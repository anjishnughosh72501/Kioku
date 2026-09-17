# Kioku Releases

This directory contains standalone release builds for Kioku.

## Current Release: V3.5

| File | Platform | Architecture | Size | SHA-256 Checksum |
| :--- | :--- | :--- | :--- | :--- |
| **[`kioku-v3.5-release.apk`](kioku-v3.5-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.8 MB | `C4A2B120F36D1F95A5C770CF1CF30962B97F74588FF9B3ADA473CA66DBB618EA` |
| **[`kioku-release.apk`](kioku-release.apk)** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 61.8 MB | `C4A2B120F36D1F95A5C770CF1CF30962B97F74588FF9B3ADA473CA66DBB618EA` |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v3.5-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v3.5-release.apk
```

---

## 📋 Release Highlights (V3.5)

### 🖼️ Instant Album Thumbnail Updates & Cover Photo Management
- **Immediate Visual Updates**: Resolved image cache collision and gesture conflicts so updating an album thumbnail instantly reflects across both the Albums hub and Album Details screen without requiring an app restart.
- **Dedicated Cover Photo Action**: Added convenient thumbnail management options inside `AlbumDetailScreen` (app bar action & cover banner overlay) and long-press support on album cards with options to pick from gallery, capture with camera, or remove thumbnail.
- **Cache-Busting Storage**: Thumbnails are stored in permanent document storage with versioned timestamp paths and memory cache eviction to avoid stale bitmap caching.

### 👤 Startup Username Onboarding Restored
- **First-Time Username Prompt**: The interactive username onboarding dialog now reliably prompts the user on startup whenever a username has not yet been chosen or is set to placeholder defaults.
- **Real-Time Feed Greeting**: As soon as the username is set, the `"Konnichiwa (user)!"` feed header immediately updates to reflect the new identity.

### 🔓 Seamless Photo Uploads & Recovery Key Lockout Removed
- **Uninterrupted Photo Uploads**: Completely removed the 24-word recovery phrase lockout mechanism and `VaultRecoveryRequiredException` that blocked photo/video uploads after clearing cache or restarts.
- **Self-Healing Key Persistence**: Master keys and album collection keys now automatically self-heal and regenerate transparently with multi-layer durable backups (`SharedPreferences` fallback), guaranteeing uploads always succeed without crashing.
- **Clean Profile Screen**: Removed the obsolete 24-words recovery phrase button from the Profile page while retaining the clean expandable Zero-Knowledge Encryption Info card.

### 🚫 Complete Removal of Email / Gmail Invites
- **Code & Link Exclusive**: Removed all email input fields, email regex validation, and Google Drive email share actions from both `AlbumDetailScreen` and `ProfileScreen`.
- **Pure Friend Codes & Share Links**: Invitations are now managed exclusively through mutual Friend Codes and one-tap shareable deep links.
- **Dedicated Invite Dialog**: Clean modal displaying Connected Friends with one-tap invite dispatch, a "Copy Link" button, and system share sheet integration.

### 🛡️ Cache-Clear Immune & Zero-Corruption Storage Retention
- **Permanent Thumbnail Storage**: Album thumbnails picked from the gallery are stored directly in permanent app document storage (`/Kioku/Thumbnails/`), completely isolated from Android's temporary `/cache` directory. Clearing cache in Android Settings will **never** delete album thumbnails.
- **Resilient Feed Loading**: Feed page loading is fully protected against empty state failures or cache wipes with auto-healing fallback.
- **Disk-Backed Physical Self-Healing**: If the index cache is cleared, `LocalStorageService` dynamically reconstructs the album memory index directly from the physical disk directory with relative path resolution.
- **Per-Album Provider Routing**: `EncryptedMemoryRepository` dynamically routes calls to `LocalStorageProvider` for device storage albums (`local_...`), preventing Google Drive 404/not-found crashes when browsing local albums.

### 🔑 End-to-End Shared Album Cryptography & Auto-Key Transfer
- **Cryptographic Key Exchange in Links**: Generated invite links include the base64url-encoded Album Encryption Key (AEK) via `&key=...`.
- **Automatic Ingestion**: When an invite link is clicked, `DeepLinkService` parses and writes the AEK into the recipient's `KeyStore`.
- **Mutual Read/Write Access**: Invited friends can immediately decrypt all existing photos and securely encrypt new uploads to the shared album.

---

## 📜 Previous Releases

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

