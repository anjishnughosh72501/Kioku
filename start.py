import subprocess
import os
import time
import socket
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
FLUTTER_DIR = os.path.join(ROOT, "flutter_mobile")
BACKEND_DIR = os.path.join(ROOT, "backend")
ANDROID_SDK = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Android", "Sdk")
ADB = os.path.join(ANDROID_SDK, "platform-tools", "adb.exe")
EMULATOR = os.path.join(ANDROID_SDK, "emulator", "emulator.exe")
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
            print(f"  WARN: {label} failed: {r.stderr.strip()}")
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
    ok, out = run([ADB, "devices"])
    return ok and "emulator" in out and "device" in out


def wait_for_device(timeout=90):
    print(f"  Waiting for emulator to boot (up to {timeout}s)...")
    start = time.time()
    while time.time() - start < timeout:
        ok, out = run([ADB, "shell", "getprop", "sys.boot_completed"])
        if ok and out.strip() == "1":
            print("  Emulator is ready.")
            return True
        time.sleep(3)
    print("  WARN: Emulator may not be fully booted.")
    return False


def main():
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
        # 1. Start Node.js Backend
        print("[1/5] Starting Node.js backend...")
        backend_already_up = is_port_in_use(BACKEND_PORT)
        if backend_already_up:
            print(f"  Port {BACKEND_PORT} in use — verifying health...")
            if check_backend_health(BACKEND_PORT, timeout=3):
                print(f"  Backend already running on http://localhost:{BACKEND_PORT}")
            else:
                print(f"  WARN: Port {BACKEND_PORT} occupied by another process.")
        else:
            node_modules = os.path.join(BACKEND_DIR, "node_modules")
            if not os.path.exists(node_modules):
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
                print(f"  Backend is up and running on http://localhost:{BACKEND_PORT}")
            else:
                print(f"  WARN: Backend health check timed out. Check {backend_log_path} for details.")

        # 2. Launch emulator if not running
        print("[2/5] Starting Android emulator...")
        if is_emulator_running():
            print("  Emulator already running.")
        else:
            procs.append(subprocess.Popen(
                [EMULATOR, "-avd", AVD_NAME, "-no-snapshot-load", "-gpu", "auto"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ))
            wait_for_device()

        # Reverse port 4000 to emulator so app can reach localhost:4000
        run([ADB, "reverse", f"tcp:{BACKEND_PORT}", f"tcp:{BACKEND_PORT}"])

        # 3. Build and install Flutter app (.bat on Windows needs shell=True)
        print("[3/5] Building and installing Flutter app...")
        print("  Getting dependencies...")
        ok, _ = run("flutter pub get", timeout=180, cwd=FLUTTER_DIR, shell=True)
        if not ok:
            print("  ERROR: flutter pub get failed.")
            cleanup()
            return
        print("  Building debug APK...")
        ok, _ = run("flutter build apk --debug", timeout=600, cwd=FLUTTER_DIR, shell=True)
        if not ok:
            print("  ERROR: flutter build apk failed.")
            cleanup()
            return
        print("  Installing debug APK...")
        ok, _ = run("flutter install --debug", timeout=600, cwd=FLUTTER_DIR, shell=True)
        if not ok:
            print("  ERROR: flutter install failed.")
            cleanup()
            return

        # 4. Launch the app on the emulator
        print("[4/5] Launching Kioku app on emulator...")
        run([ADB, "shell", "am", "force-stop", FLUTTER_APP_PACKAGE])
        time.sleep(1)
        run([ADB, "shell", "am", "start", "-n", f"{FLUTTER_APP_PACKAGE}/{FLUTTER_APP_ACTIVITY}"])

        # 5. Check Google Sign-In setup
        print("[5/5] Checking Google Sign-In OAuth setup...")
        manifest = os.path.join(FLUTTER_DIR, "android", "app", "src", "main", "AndroidManifest.xml")
        configured = False
        if os.path.exists(manifest):
            with open(manifest, encoding="utf-8") as f:
                configured = "default_web_client_id" in f.read()

        print("\n========================================")
        print("  Kioku is running!")
        print(f"  Flutter app:  {FLUTTER_APP_PACKAGE}")
        print(f"  Backend:      http://localhost:{BACKEND_PORT}")
        print("  Emulator:     connected (port 4000 reverse mapped)")
        print("  Logs:         flutter logs (in separate terminal)")
        print("  Backend Log:  backend.log")
        if not configured:
            print("")
            print("  NOTE: Google Sign-In needs OAuth setup first.")
            print("  Follow GOOGLE_SETUP.md to register the app, then run:")
            print("    flutter run")
            print("  Signing in will otherwise show an error on the emulator.")
        else:
            print("  OAuth:        Client ID configured in AndroidManifest.xml")
        print("========================================\n")
        print("  Press Ctrl+C to stop the services.")

        for p in procs:
            p.wait()

    except KeyboardInterrupt:
        print("\nShutting down...")
        cleanup()
        print("All stopped.")


if __name__ == "__main__":
    main()