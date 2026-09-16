import argparse
import os
import shutil
import socket
import subprocess
import time
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
FLUTTER_DIR = os.path.join(ROOT, "flutter_mobile")
BACKEND_DIR = os.path.join(ROOT, "backend")
ANDROID_SDK = (
    os.environ.get("ANDROID_HOME")
    or os.environ.get("ANDROID_SDK_ROOT")
    or os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")
)
ADB = shutil.which("adb") or os.path.join(ANDROID_SDK, "platform-tools", "adb.exe")
EMULATOR = shutil.which("emulator") or os.path.join(ANDROID_SDK, "emulator", "emulator.exe")
AVD_NAME = "Pixel_7_API_35"
FLUTTER_APP_PACKAGE = "com.kioku.app"
FLUTTER_APP_ACTIVITY = "com.kioku.app.MainActivity"
BACKEND_PORT = 4000


def run(cmd, timeout=15, cwd=None, shell=False, check=True):
    """Run a command capturing output. Returns (ok, stdout)."""
    label = " ".join(cmd) if isinstance(cmd, list) else cmd
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd, shell=shell)
        ok = r.returncode == 0
        if check and not ok:
            err_msg = r.stderr.strip() or r.stdout.strip()
            print(f"  WARN: {label} failed: {err_msg}")
        return ok, r.stdout.strip()
    except Exception as ex:
        print(f"  WARN: {label} failed: {ex}")
        return False, ""


def is_port_in_use(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def check_backend_health(port, timeout=10):
    url = f"http://127.0.0.1:{port}/health"
    start = time.time()
    while time.time() - start < timeout:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if response.status == 200:
                    return True
        except Exception:
            time.sleep(1)
    return False


def is_emulator_running():
    if not ADB or not os.path.exists(ADB):
        return False
    ok, out = run([ADB, "devices"], check=False)
    if not ok:
        return False
    lines = [line.strip() for line in out.splitlines() if line.strip() and not line.startswith("List of devices")]
    return any("\tdevice" in line for line in lines)


def wait_for_device(timeout=90):
    print(f"  Waiting for device/emulator to boot (up to {timeout}s)...")
    start = time.time()
    while time.time() - start < timeout:
        ok, out = run([ADB, "shell", "getprop", "sys.boot_completed"])
        if ok and out.strip() == "1":
            print("  Device is ready.")
            return True
        time.sleep(3)
    print("  WARN: Device may not be fully booted.")
    return False


def ensure_libsodium():
    """Ensure libsodium.dll exists in flutter_mobile for local test runs on Windows."""
    if os.name != "nt":
        return
    dest = os.path.join(FLUTTER_DIR, "libsodium.dll")
    if os.path.exists(dest):
        return

    pub_cache = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Pub", "Cache", "hosted", "pub.dev")
    if os.path.exists(pub_cache):
        for root, _, files in os.walk(pub_cache):
            if "libsodium.dll" in files and "Release" in root:
                src = os.path.join(root, "libsodium.dll")
                try:
                    shutil.copy2(src, dest)
                    print("  Synchronized libsodium.dll for Windows desktop/testing environment.")
                    break
                except Exception:
                    pass


def run_tests():
    print("Running Kioku verification test suites...")
    print("\n--- 1. Backend Tests (Node.js & Jest) ---")
    ok, out = run("npm test", timeout=60, cwd=BACKEND_DIR, shell=True)
    print(out)
    if not ok:
        print("Backend tests failed!")
        return False

    print("\n--- 2. Flutter Mobile Tests (E2EE Crypto, Storage & Widgets) ---")
    ensure_libsodium()
    ok, out = run("flutter test", timeout=120, cwd=FLUTTER_DIR, shell=True)
    print(out)
    if not ok:
        print("Flutter tests failed!")
        return False

    print("\nAll Kioku test suites passed successfully!")
    return True


def main():
    parser = argparse.ArgumentParser(description="Start Kioku development environment")
    parser.add_argument("--test", action="store_true", help="Run automated test suites and exit")
    parser.add_argument("--build-apk", action="store_true", help="Build the Android APK and exit")
    parser.add_argument("--release", action="store_true", help="Use release mode for building the APK (default is debug)")
    parser.add_argument("--no-emulator", action="store_true", help="Skip emulator startup (use physical device or desktop)")
    args = parser.parse_args()

    if args.test:
        success = run_tests()
        exit(0 if success else 1)

    if args.build_apk:
        ensure_libsodium()
        print("Syncing Flutter dependencies...")
        run("flutter pub get", timeout=180, cwd=FLUTTER_DIR, shell=True)
        build_mode = "release" if args.release else "debug"
        print(f"Building {build_mode} APK...")
        ok, out = run(f"flutter build apk --{build_mode}", timeout=600, cwd=FLUTTER_DIR, shell=True)
        if not ok:
            print(f"ERROR: flutter build apk failed:\n{out}")
            exit(1)
        apk_name = f"app-{build_mode}.apk"
        apk_path = os.path.join(FLUTTER_DIR, "build", "app", "outputs", "flutter-apk", apk_name)
        print(f"\nAPK built successfully: {apk_path}")
        exit(0)

    procs = []
    log_files = []

    def cleanup():
        for f in log_files:
            try:
                f.close()
            except Exception:
                pass
        for p in procs:
            if p.poll() is None:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], capture_output=True)
                else:
                    p.terminate()
        for p in procs:
            try:
                p.wait(timeout=3)
            except Exception:
                pass

    try:
        ensure_libsodium()

        # 1. Start Node.js Backend & WebRTC Signaling Relay
        print("[1/5] Starting Node.js backend & WebRTC signaling relay...")
        backend_already_up = is_port_in_use(BACKEND_PORT)
        if backend_already_up:
            print(f"  Port {BACKEND_PORT} in use — verifying health...")
            if check_backend_health(BACKEND_PORT, timeout=3):
                print(f"  Backend already running on http://localhost:{BACKEND_PORT}")
                print(f"  Signaling relay available at ws://localhost:{BACKEND_PORT}/signal")
            else:
                print(f"  WARN: Port {BACKEND_PORT} occupied by another process.")
        else:
            ws_module = os.path.join(BACKEND_DIR, "node_modules", "ws")
            if not os.path.exists(ws_module):
                print("  Installing backend dependencies (npm install)...")
                ok, _ = run("npm install", timeout=120, cwd=BACKEND_DIR, shell=True)
                if not ok:
                    print("  WARN: npm install encountered issues.")

            backend_log_path = os.path.join(ROOT, "backend.log")
            backend_log = open(backend_log_path, "w", encoding="utf-8")
            log_files.append(backend_log)

            proc = subprocess.Popen(
                ["node", "server.js"],
                cwd=BACKEND_DIR,
                stdout=backend_log,
                stderr=subprocess.STDOUT,
                shell=False,
            )
            procs.append(proc)

            if check_backend_health(BACKEND_PORT, timeout=12):
                print(f"  Backend running on http://localhost:{BACKEND_PORT}")
                print(f"  WebRTC Signaling Relay running on ws://localhost:{BACKEND_PORT}/signal")
            else:
                print(f"  WARN: Backend health check timed out. Check {backend_log_path} for details.")

        # 2. Launch emulator if requested and not running
        if not args.no_emulator:
            print("[2/5] Checking Android device / emulator...")
            if is_emulator_running():
                print("  Device/emulator already connected.")
            else:
                if os.path.exists(EMULATOR):
                    print(f"  Launching emulator '{AVD_NAME}'...")
                    procs.append(subprocess.Popen(
                        [EMULATOR, "-avd", AVD_NAME, "-no-snapshot-load", "-gpu", "auto"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    ))
                    wait_for_device()
                else:
                    print("  Android emulator executable not found. Proceeding without emulator.")

            # Reverse port 4000 to device/emulator so app can reach backend & signaling
            if os.path.exists(ADB):
                run([ADB, "reverse", f"tcp:{BACKEND_PORT}", f"tcp:{BACKEND_PORT}"])
        else:
            print("[2/5] Skipping emulator startup (--no-emulator flag active).")

        # 3. Build and install Flutter app
        print("[3/5] Syncing Flutter dependencies...")
        ok, _ = run("flutter pub get", timeout=180, cwd=FLUTTER_DIR, shell=True)
        if not ok:
            print("  ERROR: flutter pub get failed.")
            cleanup()
            return

        if not args.no_emulator and is_emulator_running():
            build_mode = "release" if args.release else "debug"
            print(f"  Building {build_mode} APK...")
            ok, out = run(f"flutter build apk --{build_mode}", timeout=600, cwd=FLUTTER_DIR, shell=True)
            if not ok:
                print(f"  ERROR: flutter build apk failed:\n{out}")
                cleanup()
                return

            print(f"  Installing {build_mode} APK...")
            apk_name = f"app-{build_mode}.apk"
            apk_path = os.path.join(FLUTTER_DIR, "build", "app", "outputs", "flutter-apk", apk_name)
            installed = False
            if os.path.exists(apk_path) and ADB and os.path.exists(ADB):
                ok_install, _ = run([ADB, "install", "-r", apk_path], timeout=120)
                installed = ok_install

            if not installed:
                ok, _ = run(f"flutter install --{build_mode}", timeout=600, cwd=FLUTTER_DIR, shell=True)
                if not ok:
                    print("  ERROR: flutter install failed.")
                    cleanup()
                    return

            # 4. Launch the app on device/emulator
            print("[4/5] Launching Kioku app on device...")
            run([ADB, "shell", "am", "force-stop", FLUTTER_APP_PACKAGE])
            time.sleep(1)
            run([ADB, "shell", "am", "start", "-n", f"{FLUTTER_APP_PACKAGE}/{FLUTTER_APP_ACTIVITY}"])
        else:
            print("[4/5] APK build & install skipped (no connected emulator/device).")

        # 5. Check configuration status
        print("[5/5] Checking configuration status...")
        manifest = os.path.join(FLUTTER_DIR, "android", "app", "src", "main", "AndroidManifest.xml")
        oauth_configured = False
        if os.path.exists(manifest):
            with open(manifest, encoding="utf-8") as f:
                oauth_configured = "default_web_client_id" in f.read()

        print("\n========================================================")
        print("  Kioku Development Environment is Ready!")
        print("========================================================")
        print(f"  Flutter Package:   {FLUTTER_APP_PACKAGE}")
        print(f"  HTTP Backend:      http://localhost:{BACKEND_PORT}")
        print(f"  Signaling Relay:   ws://localhost:{BACKEND_PORT}/signal")
        print("  Cryptography:      Ente-aligned E2EE (Sodium X25519, XChaCha20-Poly1305)")
        print("  Recovery System:   24-word BIP39 mnemonic & master key recovery")
        print("  Storage Backends:  Device, Google Drive, S3/R2/B2, WebDAV & Mesh")
        print("  Backend Log:       backend.log")
        if not oauth_configured:
            print("")
            print("  NOTE: Optional Google Sign-In needs OAuth setup.")
            print("  Follow GOOGLE_SETUP.md if using Google Drive storage mode.")
            print("  Local device storage, S3, WebDAV, and Mesh require no Google setup.")
        print("========================================================\n")
        print("  Press Ctrl+C to stop background services.")

        for p in procs:
            p.wait()

    except KeyboardInterrupt:
        print("\nShutting down services...")
        cleanup()
        print("All stopped.")


if __name__ == "__main__":
    main()