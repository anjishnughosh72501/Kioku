# Kioku — Threat Model & Security Architecture

**Document Version:** 1.0  
**Last Updated:** September 2026  
**Status:** Store & Production Ready  
**Scope:** Mobile Client (Flutter/Dart), Relay Backend (Node/Express), Cloud Storage Adapters (Drive, S3, Dropbox)

---

## 1. Overview & Security Philosophy

Kioku is designed under the **Zero-Knowledge (ZK)** and **End-to-End Encryption (E2EE)** paradigms. The foundational tenet is simple:

> **The server and third-party storage providers are untrusted entities.** Plaintext photo bytes, album titles, memory descriptions, and encryption keys must never touch the backend server, database, or transit network unencrypted.

Even in the event of a full compromise of the Kioku relay backend or third-party storage buckets, an attacker should obtain only ciphertexts indistinguishable from random noise.

---

## 2. Trust Boundaries & Architecture

`
+-------------------------------------------------------------------------+
| TRUSTED ZONE: User Device (Local Mobile Sandbox)                         |
|                                                                         |
|  +-------------------------------------------------------------------+  |
|  | Flutter / Dart Client Runtime                                      |  |
|  |  * BIP-39 12/24-word Mnemonic Key Derivation                       |  |
|  |  * Flutter Secure Storage (Android Keystore / iOS Keychain)        |  |
|  |  * SQLite (Encrypted Local Metadata Cache)                         |  |
|  |  * Libsodium Engine (crypto_secretbox, crypto_kx, Argon2id)        |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
                                    |
                            TLS 1.3 / HTTPS
                                    |
+-------------------------------------------------------------------------+
| UNTRUSTED ZONE: Transport & Relays                                      |
|                                                                         |
|  +---------------------------+       +-------------------------------+  |
|  | Kioku Relay Backend       |       | Cloud Storage Providers       |  |
|  |  * Device Secret Auth     |       |  * Google Drive               |  |
|  |  * E2EE Friend Pairing    |       |  * Dropbox                    |  |
|  |  * Encrypted Invite Relay |       |  * AWS S3 / Self-hosted       |  |
|  |  * Zero Key Knowledge     |       |  * Blob Ciphertext Only       |  |
|  +---------------------------+       +-------------------------------+  |
+-------------------------------------------------------------------------+
`

### Trust Zones
1. **Trusted Zone (Local Client Sandbox)**:
   - Client process memory, hardware-backed secure storage (Android Keystore / iOS Keychain).
   - Cryptographic primitives executed locally via native Libsodium bindings.
   - Decrypted media exists only transiently in RAM or encrypted cache for active rendering.

2. **Untrusted Zone (Network & Storage)**:
   - **Network Transit**: TLS 1.3 protects against eavesdropping, but the application assumes transit networks are hostile.
   - **Kioku Relay Server**: Handles friend pairing tokens, short-lived encrypted invitations, and sync signals. Cannot read invitation payloads.
   - **Cloud Storage**: Receives only pre-encrypted chunked payloads named by cryptographic hashes.

---

## 3. Cryptographic Key Hierarchy

Kioku implements a strict **Three-Tier Key Hierarchy**:

`
[ Root / Master Seed (BIP-39 Mnemonic) ]
                    |
                    v (Argon2id / KDF)
           [ Identity Keypair ]
           (X25519 for Key Exchange)
                    |
                    +------------------------+
                    |                        |
                    v                        v
            [ Album Key 1 ]           [ Album Key N ]
         (ChaCha20-Poly1305)       (ChaCha20-Poly1305)
                    |                        |
                    v                        v
          [ File / Chunk Keys ]     [ File / Chunk Keys ]
         (Chunked Stream Cipher)   (Chunked Stream Cipher)
`

1. **Tier 1: Master Identity & Recovery Seed**
   - BIP-39 mnemonic phrase (12 or 24 words).
   - Generates user master key and X25519 identity keypair for asynchronous key exchange (crypto_kx).
   - Never transmitted off-device; used only for device recovery and identity derivation.

2. **Tier 2: Per-Album Symmetric Keys**
   - 256-bit random keys generated via crypto_secretbox_keygen.
   - Shared between album members via X25519 asymmetric wrapping.
   - Revocation or member removal triggers album key re-wrapping.

3. **Tier 3: File & Streaming Chunk Encryption**
   - Large media files are encrypted in fixed-size chunks using Libsodium secretstream / AEAD constructions.
   - Ensures memory safety on constrained mobile hardware (prevents loading multi-gigabyte videos entirely into RAM) and defends against ciphertext truncation attacks.

---

## 4. Threat Actors & Threat Scenarios

| Threat Actor | Capabilities | Kioku Mitigation | Residual Risk |
| :--- | :--- | :--- | :--- |
| **Passive Network Eavesdropper** | Intercepts Wi-Fi / cellular traffic, monitors endpoints. | TLS 1.3 transport security + end-to-end payload encryption. Payloads are AEAD ciphertext. | Traffic volume and timing correlation (mitigated by chunking). |
| **Compromised Relay Backend** | Full root access to Node/Express server and SQLite database. | Server never receives plaintext data, album keys, or private keys. Friend requests require device-secret-authenticated JWTs. | Denial of service / message drop (mitigated by local-first offline architecture). |
| **Malicious Cloud Storage Provider** | S3/Drive administrator inspects stored objects. | All uploaded files are pre-encrypted ciphertexts with pseudorandom UUID/hash keys. Filenames and metadata are encrypted. | Storage provider knows total storage volume used. |
| **Unauthenticated Impersonator** | Attempts to poll or accept other users' friend requests via IDOR. | Enforced device secret registration (POST /friends/token) and JWT authentication. Endpoints strictly reject mismatched callers with 403 Forbidden. | None. Spoofing requires physical device secret possession. |
| **Malicious / Disgruntled Friend** | Valid member of a shared album who leaves or turns hostile. | Album re-keying on member eviction; historical data remains visible to past members, but future media uses new keys. | Disgruntled friend may retain previously exported photos. |
| **Device Theft / Physical Seizure** | Attacker has physical possession of locked or unlocked phone. | Hardware-backed keystore integration, app PIN/biometric authentication, no plaintext keys in unencrypted shared storage. | Extreme forensic extraction if device is seized in an unlocked, unencrypted state. |

---

## 5. Friend Pairing & Identity Authorization (Hardened)

In response to Security Audit item **P0-1**, the friend pairing workflow utilizes cryptographic token binding:

1. **Registration**: On first launch, the mobile client generates a cryptographically secure 256-bit riend_secret stored in FlutterSecureStorage.
2. **Token Minting**: Client sends POST /friends/token containing riendCode and secret. The backend hashes the secret with SHA-256 and issues a signed JWT (HS256, 90-day expiry).
3. **Authorized Interaction**: All friend queries (/requests/:myCode, /albums/invites/:myCode), acceptances, and declines require Authorization: Bearer <jwt>.
4. **IDOR Defense**: The equireFriendAuth middleware binds eq.authFriendCode to the JWT claims and validates that the requested resource belongs strictly to the authenticated caller.

---

## 6. Accepted Residual Risks & Future Roadmap

1. **Traffic Analysis & File Size Correlation**:
   - *Risk*: An observer watching cloud storage uploads may infer photo resolutions or video lengths based on file size.
   - *Roadmap*: Introduce random padding bytes (PKCS#7 or zero-padding) to round chunk sizes to uniform tiers.
2. **Post-Quantum Cryptography**:
   - *Risk*: Future quantum computers could theoretically compromise X25519 key exchanges retroactively.
   - *Roadmap*: Evaluate hybrid Post-Quantum Key Encapsulation (e.g., ML-KEM / Kyber + X25519) when standardized mobile implementations mature.
3. **Biometric Bypass on Rooted/Jailbroken Devices**:
   - *Risk*: On compromised operating systems, memory hooks (e.g., Frida) can intercept decrypted buffers in RAM.
   - *Guidance*: Kioku is targeted for standard Android/iOS sandbox environments. Root detection warnings are slated for v4.0.

---

## 7. Security Contact & Vulnerability Disclosure

Security issues should be reported responsibly to:  
**Email:** security@kioku-app.local (or via GitHub Security Advisories)

We ask researchers to give reasonable time for remediation prior to public disclosure.
