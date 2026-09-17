# Kioku Releases

This directory contains standalone release builds for Kioku.

## Current Release: v3.0.0

| File | Platform | Architecture | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **[`kioku-v3.0-release.apk`](kioku-v3.0-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.8 MB | `88DD0314F867D008464319EBAFA478B15199757546B31CF8570292A26B662F04` |
| **[`kioku-release.apk`](kioku-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.8 MB | `88DD0314F867D008464319EBAFA478B15199757546B31CF8570292A26B662F04` |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v3.0-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v3.0-release.apk
```

---

## 📋 Release Highlights (v3.0.0)

### 👥 Friends Management & Direct Album Invites
- **Enter Friend Code in Profile**: Dedicated "Connected Friends" section in Profile screen to add friends via their unique code (e.g., `KIOKU-XXXX`).
- **Persistent Friends List**: Friends remain visibly saved with avatar badges, friend code display, and remove options.
- **One-Tap Album Invites**: Directly invite any saved friend to any album with album selector bottom-sheet and instant link dispatch.

### 🧭 Clean Icon-Only Floating Nav Bar & De-cluttered Feed
- **Sleek Icon-Only Navigation**: Replaced text labels in the bottom navigation bar with crisp, centered iconography with smooth tooltips, eliminating multi-line text wrapping.
- **Removed Duplicate Top Bar**: De-cluttered feed header by eliminating the redundant top page shortcut bar.

### 🗂️ Dedicated Albums Hub & 2×2 Photo Grid
- **Dedicated Albums Tab**: 4-tab bottom navigation (**Feed** | **Albums** | **Flashbacks** | **Profile**) with dedicated album management.
- **2×2 Square Photo Grid**: Clean, edge-to-edge 2×2 photo grid in album details for dense, distraction-free visual browsing.
- **Shareable Deep Links & Invites**: One-tap album invite links generating app-accessible URLs and `kioku://album/<id>` deep links.

### 🎨 High-Contrast Dark Theme & Streamlined UI
- **Enhanced Forest Dark Theme**: Deep rich roasted bean canvas (`#0F0B08`), high-contrast oat grey text (`#B09E92`, WCAG AA compliant), and warm golden caramel accents (`#E5AF72`).
- **First-Launch Friction Removed**: Direct feed access without forcing a blocking username/friend-code dialog.
- **Screen-Reader Accessibility**: Added `ExcludeSemantics` to decorative washi tape and hanko elements.

### 🛡️ Zero-Knowledge End-to-End Encryption (E2EE)
- **libsodium Cryptographic Engine**: Industrial-grade `XChaCha20-Poly1305` chunked streaming encryption for media and `crypto_secretbox` for metadata.
- **Three-Tier Key Hierarchy**: MasterKey in hardware-backed keystore, per-album CollectionKeys, and per-media FileKeys.
- **BIP39 24-Word Recovery Phrase**: Standard mnemonic key recovery with 60s clipboard auto-clear and secondary vault recovery backup in `SharedPreferences`.

---

## 📜 Previous Releases

<details>
<summary><b>v2.0.0</b> (2026-09-16)</summary>

- Multi-Cloud BYOS: Google Drive, S3, WebDAV, Local, Mesh.
- Flashbacks engine with smart retrospective grouping.
</details>

<details>
<summary><b>v1.0.0</b> (2026-09-10)</summary>

- Initial preview release with Japanese stationery aesthetic, offline local storage, and Google Drive sync.
</details>
</details>
