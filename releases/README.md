# Kioku Releases

Official standalone release builds for Kioku are distributed via [GitHub Releases](https://github.com/anjishnughosh72501/Kioku/releases) and packaged in the `releases/` directory.

### Current Release: V3.8

| File | Platform | Architecture | Size | SHA-256 Checksum | GitHub Release |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`kioku-v3.8-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 63.5 MB | `FB395EAD63023C324FA2DDBBFA5E469F8334423663B19EFB171467F7081885C9` | [Download v3.8](https://github.com/anjishnughosh72501/Kioku/releases/tag/v3.8) |
| **`kioku-release.apk`** | Android 5.0+ (API 21+) | Universal (`arm64-v8a`, `armeabi-v7a`, `x86_64`) | 63.5 MB | `FB395EAD63023C324FA2DDBBFA5E469F8334423663B19EFB171467F7081885C9` | [Latest Release](https://github.com/anjishnughosh72501/Kioku/releases/latest) |

---

## 📲 Installation Instructions

### Option 1: Direct Device Install (Phone)
1. Download `kioku-v3.8-release.apk` (or `kioku-release.apk`) directly to your Android device.
2. Open the downloaded file from your browser's downloads or file manager.
3. If prompted, enable **"Install unknown apps"** for your browser or file manager in Android Settings.
4. Tap **Install** and launch Kioku.

### Option 2: Via ADB (Command Line)
Connect your Android device with USB debugging enabled (or start an emulator) and run:
```bash
adb install -r releases/kioku-v3.8-release.apk
```

---

## 📋 Release Highlights (V3.8)

### 🔗 Universal Short Invite Links (`kioku.app/i/:code`)
- **6-Character Cryptographic Invite Codes**: Unambiguous 32-character codes with 30-day TTL stored in an indexed backend database.
- **Content-Negotiated Resolution**: Web browsers get a styled warm-coffee landing page with dynamic inviter card and `"Open Kioku App"` button; API and apps receive instant JSON resolution.
- **Deep Linking & Cold Starts**: Android & iOS app links (`kioku://i/:code` and `https://kioku.app/i/:code`) route directly to confirmation. Unauthenticated cold starts persist the invite code and prompt seamlessly upon sign-in/onboarding.

### 👥 4-Tab Dedicated Social Hub
- **Friends Tab**: View friends, manage album sharing, and remove connections with optimistic cache updates.
- **Incoming Tab**: Relative timestamps, inviter name & code, with optimistic 1-tap **Accept** and **Decline**.
- **Sent Tab**: Track outgoing requests with status badges (`Pending` vs `Expired`) and 1-tap **Cancel** or **Resend**.
- **Add Tab**: Method A (Friend Code input with inline validation) and Method B (Paste short link or code to open confirmation dialog).
- **Live Unread Badges**: Real-time incoming badge counter on top app bar and tab bar.

### 📱 Redesigned Sharing Sheet & QR Codes
- Modern share sheet with 1-tap friend code copy, 1-tap short link copy, and native system share sheet (`share_plus`).
- Pure Dart CustomPainter QR code generator (`qr_flutter`) encoding strictly `https://kioku.app/i/:code`.

---

## 📜 Previous Releases

<details>
<summary><b>v3.7.0</b> (2026-09-18)</summary>

- **First-Setup Username Selection**: Mandatory non-repeating username prompt after Local Storage or Google Auth.
- **App Lock & Privacy Gate**: Auto-resume biometric/PIN lock, PIN keypad, and BIP-39 recovery fallback.
- **Security Audit Phases 1–4**: Hardened JWT token minting, atomic SQLite buffer swapping, PII-scrubbed telemetry, and horizontal scaling mesh signaling.
- **SHA-256**: `24D4B34D20E20414165323476253DFA700D55BF711FB94F56715E71D816A9FFD`
</details>

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
