# Encryption export-compliance policy

This document explains why the iOS app declares
`ITSAppUsesNonExemptEncryption = false` in `app/Sources/App/Info.plist` and
why no U.S. Encryption Registration Number (ERN) is required for the v1
TestFlight / App Store submission.

> ⚠️ **Not legal advice.** This file is an engineering record of the
> encryption surface that exists in the codebase today. The export-compliance
> classification below should be re-validated by qualified counsel or an
> export-compliance specialist before each App Store submission, and
> immediately whenever the cryptography surface changes (see
> [When this declaration must change](#when-this-declaration-must-change)).

## Declaration

| Key | Value | Where |
|---|---|---|
| `ITSAppUsesNonExemptEncryption` | `false` | `app/Sources/App/Info.plist` |

When the key is `false`, App Store Connect skips the U.S. Encryption
Registration Number (ERN) prompt and the build proceeds straight to
TestFlight / App Store distribution.

## Cryptography surface in v1

The app relies exclusively on **standard TLS/HTTPS** provided by Apple
platform frameworks. Specifically:

- **`URLSession` over `https://`** for all network calls:
  - `app/Sources/Backend/Networking/APIClient.swift` — value-compass backend.
  - `app/Sources/Backend/Networking/MassiveAPIKeyValidator.swift` — Massive
    API key validation against `https://api.massive.com`.
- **Keychain Services (`SecItem*`)** for at-rest storage of the user-supplied
  Massive API key:
  - `app/Sources/Backend/Networking/MassiveAPIKeyStore.swift`.
- **No application-level cryptography.** v1 does not import `CryptoKit`,
  `CommonCrypto`, OpenSSL, BoringSSL, or any other crypto library to
  encrypt, decrypt, sign, hash, or derive keys for app-defined payloads.
  Keychain entries are protected by the OS, not by app-level encryption,
  and the SwiftData store on disk is unencrypted (Apple's File Protection
  class is the OS-level protection).

## Why `false` is correct

Standard TLS/HTTPS via Apple-provided frameworks is **exempt** from U.S.
encryption export controls under the Export Administration Regulations
(EAR) §740.17 (b)(1) for ancillary cryptography and §740.13(e) for
publicly available cryptographic source code in commercial,
off-the-shelf (COTS) software, because:

1. The cryptography is **not the app's primary function** — the app
   computes value-averaging contributions; it merely uses HTTPS as a
   transport.
2. The app does not **implement, modify, or extend** any cryptographic
   primitive — it consumes Apple's `URLSession` defaults.
3. The app does not **make cryptography available to other software**
   (no embedded libraries, no published APIs that expose crypto).

Apple's developer documentation on export compliance also calls out
"makes use of standard encryption algorithms instead of, or in addition
to, using or accessing the encryption" in iOS — exactly the v1 surface.
See <https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations>.

## When this declaration must change

Flip `ITSAppUsesNonExemptEncryption` to `true` and obtain (or update) an
ERN **before** shipping any of the following:

- Bundling a non-Apple cryptography library (OpenSSL, BoringSSL,
  libsodium, custom builds of CryptoSwift, etc.).
- Adding end-to-end encryption (E2EE) of user content for backup, sync,
  or sharing — i.e., any path where the app, not the OS, encrypts data
  before it leaves the device.
- Using `CryptoKit` / `CommonCrypto` to encrypt SwiftData payloads,
  exported files, or Keychain blobs the app itself wraps before storing.
- Implementing a Sign-in-with-Massive flow that derives session keys or
  signs payloads with anything beyond TLS client authentication.
- Adding any feature that performs or exposes **end-user-controllable
  encryption** (password-protected exports, encrypted shares, etc.).

Adding HTTPS to a new endpoint, switching to HTTP/3, or adding ATS
exceptions is **not** a trigger — those are still standard transport
crypto.

## How to update this declaration

If a future change adds non-exempt cryptography:

1. Edit `app/Sources/App/Info.plist`:
   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <true/>
   ```
2. Update this file with the new cryptography surface and the ERN/ECCN
   classification reached with counsel.
3. Update the TestFlight readiness checklist
   (`docs/testflight-readiness.md`) with the new ERN reference.
4. Submit (or refresh) the U.S. Encryption Registration Number (ERN) on
   the Bureau of Industry and Security (BIS) SNAP-R portal **before**
   the next App Store submission.

## References

- Apple — *Complying with Encryption Export Regulations*:
  <https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations>
- Apple — *Export Compliance Overview*:
  <https://developer.apple.com/support/export-compliance/>
- U.S. EAR §740.17 (License Exception ENC) and §740.13(e) (TSU):
  <https://www.bis.doc.gov/index.php/regulations/export-administration-regulations-ear>
