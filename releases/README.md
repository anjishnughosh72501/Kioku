# Kioku Releases

This directory contains standalone release builds for Kioku.

### Current Release: V3.6

| File | Platform | Architecture | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **[`kioku-v3.6-release.apk`](kioku-v3.6-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.4 MB | `3E6DB93E498EA8F34DCC868DA08CF57E3E601C9CEC6E10C4FCEE4B8B063F4937` |
| **[`kioku-release.apk`](kioku-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.4 MB | `3E6DB93E498EA8F34DCC868DA08CF57E3E601C9CEC6E10C4FCEE4B8B063F4937` |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v3.6-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v3.6-release.apk
```

---

## 📋 Release Highlights (V3.6)

### 🤝 Bidirectional Friend Requests & Cross-Account Synchronization
- **Two-Way Friend Confirmation**: Sending friend requests now requires recipient acceptance with dual-polling and automated acknowledgment (`POST /friends/ack`), immediately connecting friends on both devices.
- **In-App Album Invites**: Invite connected friends directly to albums using zero-knowledge single-use claim tokens (`crypto_box_seal`) without exposing collection keys.
- **Instant Album Joining**: Incoming album invites appear on the profile screen with Join and Decline options, unsealing keys and updating the feed in real-time.
- **Member Roster Sync**: Tracks active album participants dynamically with local storage persistence.

### 🛡️ Store Publishing Readiness & Security Hardening
- **Zero Raw Key Leakage**: Eliminated collection key exposure in URLs and QR deep links.
- **Store-Ready First Time UX**: Added branded Japanese aesthetic splash screen, 3-page interactive onboarding walkthrough, and offline Privacy Policy & Terms of Service viewer.
- **Dead Code Cleanup & Optimization**: Pruned 500+ lines of unreferenced dead code and empty widget modules; 0 analyzer issues across the entire codebase.
- **Robust Error Resilience**: Zone-guarded global exception handlers, safe temporary video decryption cleanup, and hardware-backed keystore master key protection.

---

## 📜 Previous Releases

<details>
<summary><b>v3.5.0</b> (2026-09-18)</summary>

- Instant album thumbnail updates & cover photo management.
- Cache-busting storage for local thumbnails.
- Startup username onboarding restored.
- Seamless photo uploads & recovery key lockout removed.
</details>

<details>
<summary><b>v3.2.0</b> (2026-09-17)</summary>

- Deep linking & automatic mutual friend connections.
- Elimination of feed image glitches and flickering.
- Album thumbnails with centered morphing typography.
- Per-album storage backend selection and immutability.
</details>

<details>
<summary><b>v3.0.0</b> (2026-09-17)</summary>

- Friends Management & Direct Album Invites.
- Clean Icon-Only Floating Nav Bar & De-cluttered Feed.
- Dedicated Albums Hub & 2×2 Photo Grid.
- High-Contrast Dark Theme & Zero-Knowledge End-to-End Encryption.
</details>

<details>
<summary><b>v2.0.0</b> (2026-09-16)</summary>

- Multi-Cloud BYOS: Google Drive, S3, WebDAV, Local, Mesh.
- Flashbacks engine with smart retrospective grouping.
</details>

<details>
<summary><b>v1.0.0</b> (2026-09-10)</summary>

- Initial preview release with Japanese stationery aesthetic, offline local storage, and Google Drive sync.
</details>

