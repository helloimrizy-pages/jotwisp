# Verification

## Public-release preparation — 17 September 2026

- Both source and `APP_STORE` compilation branches passed all **29 tests**.
- Xcode Release compiled the App Store executable for **arm64 and x86_64**.
  This was an unsigned build, not a signed sandbox runtime test or submission.
- Store executable imports RegisterEventHotKey and InstallEventHandler; inspection
  found no CGEventTap or AXIsProcessTrusted imports. The store shortcut is ⌃⌥V.
- Source preview packaged separately at `build/ReleasePreview/Jotwisp.app` and
  passed strict local code-signature validation. The running app was not replaced.
- Both bundles passed identity, executable, privacy manifest, offline
  support/privacy/license, and seven transparent icon-resolution checks.
- Plist, entitlement, project, shell syntax, listing field lengths, intended
  public URLs, and US$9.99 price passed local validation.
- [First public CI run](https://github.com/helloimrizy-pages/jotwisp/actions/runs/35215276910)
  passed source/store tests, source packaging, universal store compilation, and
  both bundle checks. Repository permission is read-only; no signing secrets
  are used. Checkout is pinned; Dependabot opened an upgrade proposal.
- The MIT source is public at `helloimrizy-pages/jotwisp`. Unauthenticated checks
  returned HTTP 200 for the repository, logo, support and privacy pages.
  No App Store listing, upload, or purchase availability is claimed.
- With the owner's approval, created Apple Development, Apple Distribution, and
  Mac Installer Distribution signing identities, retaining existing certificates.
  Installed Apple's verified WWDR G3 intermediate without trust overrides.
- A universal signed archive was created at `build/Jotwisp.xcarchive` and passed
  strict code-signature validation. Xcode exported an App Store distribution
  package at `build/AppStoreExport/Jotwisp.pkg`, using a new Mac Team Store
  provisioning profile for `app.textdump.mac`. Installer signature validation passed.
  The distribution summary confirms sandbox, user-selected file read/write,
  and Apple application/team identity entitlements; no network entitlement.
- Signing configuration and all certificates, profiles, logs, and build products
  remain outside Git. Nothing has been uploaded to App Store Connect or submitted.
- Required before release: signed sandbox runtime QA
  (including real cross-app capture);
  screenshots using synthetic text; store agreements/account disclosures;
  listing completion, review, and manual release.

The historical measurements below apply to earlier local builds, not the new
universal App Store build. Intel and minimum-supported macOS runtime testing
remain pending. Everyday drafts were not used as public release assets.

## Jotwisp rebrand — 17 September 2026

- Built `build/Jotwisp.app` version 1.1.0 (2), with Jotwisp as the executable name, display name, window title, sidebar heading, and menu branding.
- Exported the user-approved paper-j artwork to the full macOS `.icns` size set. Visually inspected the 512-pixel export: clean transparent corners and preserved mark/shading. The sidebar now uses the bundled application icon.
- All 27 XCTest cases passed, including two new tests for preserving existing library and workspace identities. Bundle checks verified the name, executable, stable bundle identifier, all seven icon resolutions, and transparent corners. Plist lint, shell syntax, and strict code-signature validation passed.
- Kept `app.textdump.mac`, `TextDumpWorkspace`, and `Application Support/Text Dump` unchanged. No draft migration or privacy permission changes were performed.
- Quit the old app normally. Preserved its bundle at `build/TextDump-before-Jotwisp.app-backup` (rename back to `.app` to recover it). This keeps the previous build without leaving two normal `.app` bundles with the same identifier.
- After the user approved launch, opened Jotwisp successfully. Native UI inspection confirmed the Jotwisp window/menu name, the new paper-j sidebar icon, the existing selected draft and its text, word wrapping, and “Saved locally” status. The app reports that this rebuilt copy still needs Accessibility access; no system permissions were changed and cross-app capture was not retested. The Dock itself was not visually inspected; the bundled icon passed the asset checks above.

## Permission-refresh update — 16 September 2026

All 25 tests passed after this update, including asynchronous permission recognition while the app is inactive, stopping retries once ready, and restarting retries after revocation. These permission transitions use simulated status checks; they do not grant actual system access. The release app builds and passes `codesign --verify --strict`; the build script passes `bash -n`.

The previously running app still reported missing Accessibility access. Its ad-hoc designated requirement was tied to its binary hash, and no valid signing identity was available. A stale grant after rebuilding is the likely cause, not independently confirmed from the privacy database. No system permission was changed. The app was quit normally for replacement; relaunch of the updated build was blocked pending action-time approval. On-screen verification of the updated setup sheet and a real cross-app capture remain pending.

Tested on this Apple silicon Mac with macOS 26.6.2 and Swift 6.3.3, using an optimized release build.

## Automated checks

22 XCTest cases passed with no failures. Coverage includes automatic saving without a manual save, latest-write ordering, save failure and retry, relaunch state, stale search results, title behavior, Unicode match ranges, CRLF/CR/LF line numbering, corrupted metadata preservation, interrupted first-save recovery, Trash/restore/deletion, highlighting bounds/size limits, and quick capture.

Quick-capture tests use a separate named macOS pasteboard: exact text/spacing survives in a new saved draft, the previous draft and clipboard remain unchanged, and empty/non-text data creates no draft. Chord tests cover Command+C+D, key-repeat suppression, normal Copy, ordinary Command-D, and releasing C before D. Cross-app chord delivery requires the user to enable Accessibility; that permission is not granted by the tests.

## Performance

| Check | Result |
| --- | --- |
| Packaged app size | Approximately 1.4 MiB |
| Library load: 1,001 drafts / 15,729,913 UTF-8 bytes | 61.9 ms |
| Full-library literal search, same fixture | 96.2 ms, excluding the 120 ms input debounce |
| App initialization to window ready, 1,001 drafts | 416.8 ms |
| App initialization to window ready, small library | 141–190 ms across QA launches |

These are local measurements, not guarantees on other Macs. Window-ready timing starts inside the app; it does not measure a fully cold launch from the Finder click. The library fixture contains 1,000 drafts of roughly 10 KB and one 5 MB / 120,000-line draft.

## Native UI checks

- Pasted a Markdown table and Unicode text; checked line numbers and spacing visually.
- Created a second draft, searched across drafts, inspected snippets/line numbers, and selected the correct Unicode match.
- Used native find/replace and undid the replacement.
- Quit/reopened and verified text, selected draft, and selection restoration.
- Selected JavaScript and checked syntax colors.
- Exported a draft, compared its bytes with the stored text using `cmp`, and imported it as a separate draft with its language inferred.
- Renamed a draft, moved it to Trash, and restored it.
- Checked horizontal scroll restoration, optional wrapping, and logical line numbers.
- Inspected light and dark appearances. Dark testing used an app-only override; system appearance was not changed.
- Opened the 5 MB draft, jumped to its end, and inserted text on line 120,001.
- Validated the packaged app's local code signature.

QA and performance fixtures are in ignored `build/` subdirectories and are separate from the everyday Application Support library. Permanent deletion was exercised in automated temporary-directory tests, not against user drafts.

## Known first-version limits

- Lightweight lexical highlighting, not a full programming-language parser; highlighting pauses above 1 MB.
- Undo history clears when switching drafts and is not stored across launches.
- Local storage only, with no cloud sync or revision history; an abrupt crash can lose typing not yet flushed to disk.
- The app is locally signed for this Mac, not notarized for public distribution. The packaged binary targets Apple silicon and macOS 14+; earlier macOS versions and Intel hardware were not tested here.
