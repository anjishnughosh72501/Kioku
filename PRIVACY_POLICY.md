# Privacy Policy for Kioku (記憶)

**Last Updated**: September 18, 2026  
**Effective Date**: September 18, 2026  

Kioku ("we", "our", or "us") is committed to protecting your privacy through **zero-knowledge, end-to-end encrypted, local-first architecture**. This Privacy Policy explains our cryptographic privacy guarantees, what minimal data may be processed, and your complete rights over your personal memories.

---

## 1. Zero-Knowledge Cryptographic Architecture

Kioku is fundamentally engineered so that **no third party—including Kioku operators, cloud infrastructure providers, or unauthorized peers—can access, view, or decrypt your personal photos, videos, or album contents**.

- **Client-Side Encryption**: All photos, videos, thumbnails, and metadata are encrypted on your local device before transmission or cloud storage using **libsodium** primitives:
  - Streaming authenticated encryption using `crypto_secretstream` (chunked XChaCha20-Poly1305).
  - Multi-tier key hierarchy: Master Key (device-held in hardware keystore) → Collection/Album Key (wrapped per album) → File Key (ephemeral, per media item).
- **Zero Raw Key Transmission**: Album invitations and key exchanges utilize anonymous public-key sealed boxes (`crypto_box_seal`) and single-use claim tokens. Raw cryptographic keys never traverse networks or URLs in plaintext.
- **BIP39 Seed Recovery**: Vault derivation and backup utilize a 256-bit entropy 24-word recovery phrase held solely by you.

---

## 2. Information We DO NOT Collect

- We **do not** collect, store, scan, or analyze your photos, videos, audio, or media contents.
- We **do not** use facial recognition, content indexing, artificial intelligence training, or metadata extraction on your photos.
- We **do not** collect advertising identifiers (GAID/IDFA), tracking cookies, or third-party behavioral analytics.
- We **do not** sell, rent, monetize, or broker any personal data.

---

## 3. Information Handled Ephemerally or Locally

### A. Local Storage on Your Device
- Your photos, encrypted envelopes, usernames, friend codes, and cryptographic vaults reside directly in your device's application sandbox and hardware-backed keystore (`flutter_secure_storage` with Android `EncryptedSharedPreferences` / iOS `Keychain`).
- You have 100% ownership and control over this data at all times.

### B. Personal Cloud Storage (BYOS — Bring Your Own Storage)
- If you link personal storage backends (Google Drive, Amazon S3, WebDAV, or local backups), your device communicates directly with your storage provider using your authorized credentials.
- All stored blobs are opaque, authenticated ciphertext that only you and explicitly invited circle members can decrypt.

### C. Signaling & Social Coordination (Self-Hosted / Optional Backend)
- **Friend Requests & Album Invites**: When sending two-way friend requests or album invitations, your public friend code, chosen nickname, and zero-knowledge claim tokens are temporarily coordinated by the signaling server.
- **Ephemeral WebRTC Signaling**: P2P mesh transfers utilize isolated signaling rooms to negotiate direct device-to-device connections. Media blobs transfer peer-to-peer and are end-to-end encrypted.
- **Server Logs**: Minimal operational logs (IP address and timestamp for rate-limiting and DDoS mitigation) may be temporarily processed in memory and pruned periodically.

---

## 4. Third-Party Services

- **Google Drive API**: If you choose Google Drive as a storage provider, authentication is conducted directly via Google OAuth. Kioku requests only `drive.file` scope (access strictly limited to files created by Kioku).
- **Amazon S3 / WebDAV**: Used strictly for encrypted blob storage as configured by you.

---

## 5. Data Deletion and Portability (GDPR & CCPA Rights)

Because Kioku is local-first:
- **Instant Local Deletion**: Deleting a memory overwrites it with zeroed buffers (`SecureDelete`) before unlinking from flash storage.
- **Complete Data Purge**: Clearing app data or uninstalling the app permanently removes all local keys and memories from the device.
- **Account Disconnect**: You can disconnect cloud providers at any time directly in Settings.
- **Full Data Export**: You can export any memory or album at any time directly to your device gallery or local storage.

---

## 6. Children's Privacy

Kioku does not knowingly collect or solicit personal information from children under the age of 13.

---

## 7. Contact Us

For security questions, vulnerability disclosures, or inquiries regarding this Privacy Policy, please open an issue or security advisory on our official repository:  
https://github.com/anjishnughosh72501/Kioku
