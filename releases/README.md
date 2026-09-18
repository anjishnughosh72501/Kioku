# Kioku Releases

Official standalone release builds for Kioku are distributed via [GitHub Releases](https://github.com/anjishnughosh72501/Kioku/releases) and packaged in the `releases/` directory.

### Current Release: V3.7

| File | Platform | Architecture | Size | SHA-256 Checksum | GitHub Release |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`kioku-v3.7-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.6 MB | `827077E3613BF08A0895C4CF8CDFE2094E6F2D64CF2AD42F329ABB10E6AAA230` | [Download v3.7](https://github.com/anjishnughosh72501/Kioku/releases/tag/v3.7) |
| **`kioku-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 62.6 MB | `827077E3613BF08A0895C4CF8CDFE2094E6F2D64CF2AD42F329ABB10E6AAA230` | [Latest Release](https://github.com/anjishnughosh72501/Kioku/releases/latest) |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v3.7-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v3.7-release.apk
```

---

## 📋 Release Highlights (V3.7)

### 🔒 App Lock & Privacy Gate (P1-8)
- **Automatic Resume Lock**: Re-locks the decrypted photo gallery and album view whenever Kioku returns from the background.
- **PIN Keypad Overlay**: Tactile numeric PIN lock screen with custom dot indicators and instant verification.
- **BIP-39 Recovery Fallback**: "Forgot PIN?" flow allows resetting credentials seamlessly using the user's 24-word backup recovery mnemonic phrase.
- **User Preference Management**: Enable/disable App Lock and manage PINs directly from the Profile screen.

### 🛡️ Complete Security Audit Roadmap Implementation (Phases 1–4)
- **Hardened Friends & Invites Authorization (P0-1)**: Device-secret authenticated token minting (`POST /friends/token`) with SHA-256 hashed storage and signed JWT authorization preventing all IDOR vectors.
- **Atomic Datastore Persistence (P1-5)**: Atomic SQLite buffer swapping (`retro.db.tmp` -> `retro.db`), process termination exit flush hooks, and transactional wrapper (`db.transaction()`).
- **Comprehensive Negative Security Test Suites (P2-9)**: Expanded automated test suites covering expired tokens, tampered JWT signatures, malformed headers, claim token replay defense, and full streaming envelope encrypt/decrypt round-trip verification.
- **Privacy-Preserving PII-Scrubbed Error Telemetry (P2-10)**: Local ring buffer error reporter scrubbing file paths, emails, JWTs, and recovery seeds; in-app scrubbed log viewer and export tool.
- **Horizontal Scaling Signaling Architecture (P2-12)**: Pluggable WebRTC mesh signaling store supporting single-node in-memory mode and multi-node distributed Redis pub/sub.
- **Threat Model & Release Signing (P0-2, P2-11)**: Production-grade release signing guards in `build.gradle.kts` and formal zero-knowledge threat model documentation (`THREAT_MODEL.md`).

---

## 📜 Previous Releases

<details>
<summary><b>v3.6.0</b> (2026-09-18)</summary>

- **First-Startup Only Google Sign-In & Username**: Restricts Google auth prompts and nickname dialogs strictly to the initial launch, booting straight to Feed on later startups.
- **Strict Album Scoping & Filtering**: Isolates photos per album and provides an interactive dropdown filter in the feed.
- **Two-Way Friend Request Confirmation**: Added mutual request accept/decline flows and cross-account synchronization.
- **Store Publishing Readiness**: Store-ready Privacy Policy, Terms of Service, and zero raw keys in URLs.
- **SHA-256**: `A432781EDC5E8729261BB0013FC6DC7D2D0762EF9FF57AEBE735A5C3EDE6E857`
</details>

<details>
<summary><b>v3.5.0</b> (2026-09-18)</summary>

- **Two-Way Friend Confirmation**: Asynchronous friend pairing with acceptance/rejection flows.
- **In-App Album Invites**: Zero-knowledge single-use claim tokens for peer-to-peer album sharing.
- **SHA-256**: `3E0C1CFBD673F1C40DE64F2ECB84F0744047D4C82A2E2F80735EC7DB6628A437`
</details>

<details>
<summary><b>v3.2.0</b> (2026-09-17)</summary>

- Multi-Cloud BYOS Storage (Local, Google Drive, S3/R2/B2, WebDAV, Mesh).
- BIP-39 24-word recovery phrase generator & vault recovery tool.
</details>

<details>
<summary><b>v3.0.0</b> (2026-09-17)</summary>

- Ente-aligned 3-tier key hierarchy, chunked XChaCha20-Poly1305 streaming encryption.
</details>
