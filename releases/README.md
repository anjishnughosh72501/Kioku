# Kioku Releases

Official standalone release builds for Kioku are distributed via [GitHub Releases](https://github.com/anjishnughosh72501/Kioku/releases).
Binary artifacts (`.apk`) are managed outside the Git tree to keep repository clone size minimal while providing cryptographic verification hashes below.

### Current Release: V3.6

| File | Platform | Architecture | Size | SHA-256 Checksum | GitHub Release |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`kioku-v3.6-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.4 MB | `A432781EDC5E8729261BB0013FC6DC7D2D0762EF9FF57AEBE735A5C3EDE6E857` | [Download v3.6](https://github.com/anjishnughosh72501/Kioku/releases/tag/v3.6) |
| **`kioku-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.4 MB | `A432781EDC5E8729261BB0013FC6DC7D2D0762EF9FF57AEBE735A5C3EDE6E857` | [Latest Release](https://github.com/anjishnughosh72501/Kioku/releases/latest) |

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

### 🚀 Streamlined First-Time Startup & Frictionless Subsequent Launches
- **First-Startup Exclusive Setup**: Google Sign-In and Username/Nickname prompts appear strictly on first app install/startup.
- **Zero-Friction Later Startups**: Subsequent launches bypass all auth screens and dialogs completely, booting straight into the memories feed (`/`) in under 1 second.
- **Silent Background Session Restoration**: Active Google Drive sessions restore transparently in the background without blocking the UI or redirecting away on temporary network drops.

### 🗂️ Per-Album Memory Isolation & Feed Filtering
- **Strict Album Scoping**: Fixed the issue where all memories showed repeatedly across every album. Each album now strictly loads and renders only its own photos and videos across Local storage, Google Drive, and multi-cloud providers.
- **Interactive Feed Album Filtering**: The main feed header features a sleek dropdown allowing users to filter memories by specific album or view all updates.
- **Targeted Memory Uploads**: When uploading new memories, users can select the destination album directly, ensuring correct key assignment and cache invalidation.

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

