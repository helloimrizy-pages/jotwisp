# Releasing Jotwisp

## Release decisions

- Public source: [helloimrizy-pages/jotwisp](https://github.com/helloimrizy-pages/jotwisp).
- Source license: MIT. Public contact: `rizy.izy15@gmail.com`.
- Mac App Store: **US$9.99**, paid up front; no subscription or in-app purchase.
- App Store shortcut: **Control–Option–V**. Source shortcut: literal **Command+C+D**.
- Deployment target: macOS 14. Universal App Store build: arm64 and x86_64.
- Keep release manual until the owner has checked the live product page.

This file is a checklist, not evidence of publication or Apple approval.

## 1. Public source

- [x] Inspect all staged files; exclude libraries, QA data, signing material,
  personal screenshots, credentials, build output, and local account settings.
- [x] Create the public `helloimrizy-pages/jotwisp` repository without a generated
  README/license, then push the audited main branch. Do not overwrite an existing repo.
- [x] Set description: “A quiet, native macOS scratchpad. Autosaving drafts,
  global search, and quick clipboard capture.” Topics: macos, swift, swiftui,
  appkit, notes, text-editor, privacy.
- [x] Verify public README, icon, support and privacy URLs without authentication;
  confirm GitHub recognizes the MIT license.
- [x] Check CI passes on GitHub. The workflow has read-only access, no signing
  secrets, and does not publish binaries or submit to Apple.

Optional GitHub CLI commands after the owner has authenticated:

```sh
gh auth status
gh repo create helloimrizy-pages/jotwisp --public --source=. --remote=origin --push \
  --description 'A quiet, native macOS scratchpad. Autosaving drafts, global search, and quick clipboard capture.'
```

Run only after the initial audited commit exists and the target is confirmed
absent. Public source does not mean an unsigned developer build is ready for
public binary distribution. Do not upload the local ad-hoc app as a signed release.

## 2. Apple account and signing

- [x] In Xcode → Settings → Accounts, sign in to the paid developer team.
  Membership alone does not install signing certificates on this Mac.
- [ ] Confirm the legal seller name and Team ID with the account holder.
- [ ] Register/verify the explicit App ID `app.textdump.mac`. If unavailable,
  resolve a new identifier and migration implications before changing code.
- [ ] Copy `Config/Signing.example.xcconfig` to the ignored
  `Config/Signing.local.xcconfig` and set DEVELOPMENT_TEAM. Never commit keys,
  certificates, profiles, Apple credentials, or App Store Connect API keys.
- [ ] In Xcode, select the Jotwisp scheme and configure automatic signing using
  the intended team. Have the owner authorize any certificate/profile creation.
- [ ] Account holder completes the Paid Apps Agreement, tax, banking, and trader
  status/disclosures in App Store Connect. These are private legal/account steps.

## 3. Verify, archive, upload

```sh
bash scripts/check-release.sh
bash scripts/test.sh
bash scripts/test.sh -Xswiftc -DAPP_STORE
bash scripts/build-appstore.sh --check
# After configuring signing:
bash scripts/build-appstore.sh --archive
```

- [ ] Check version/build in Resources/Info.plist; increment build for each upload.
- [ ] Test the signed sandboxed app: clipboard capture from another app, shortcut
  conflict/retry, new draft, autosave, quit/relaunch, import/export, search,
  wrap/resize, Trash restore, and all Help items. Test on macOS 14 and Intel
  hardware as well as current Apple Silicon where available.
- [ ] Inspect the signed app's entitlements: sandbox and user-selected file
  read/write only. Confirm no Accessibility event-tap symbols in the store binary.
- [ ] Test a fresh sandbox, preserving all everyday drafts. Source and store
  editions have separate libraries; verify the documented export/import path.
- [ ] Use Xcode Organizer → Distribute App → App Store Connect to validate and
  upload the archive. Resolve validation warnings; compile success is not approval.

## 4. App Store listing

- [ ] Create a macOS app named Jotwisp, primary language English (US), with the
  registered bundle ID and a private SKU such as `jotwisp-macos`.
- [ ] Copy the reviewed text from `app-store/en-US.json` and review notes from
  `app-store/REVIEW-NOTES.md`. Replace any draft-only operational status fields;
  the JSON is a preparation file, not an App Store Connect upload format.
- [ ] Confirm support/privacy URLs are public and reachable before using them.
- [ ] Complete Apple's current age-rating questionnaire truthfully. The app has
  no social feed, ads, web browser, or developer-provided mature content.
- [ ] Complete app privacy using the actual shipped build. Intended answer:
  no data collected by the app; review support handling and Apple's definitions
  before certifying. Verify the bundled privacy manifest against API usage.
- [ ] Set United States as the base territory and select **US$9.99** one-time
  price. Review regional prices and explicitly choose territories. Do not create IAPs.
- [ ] Have the owner complete EU trader/contact disclosures, content rights,
  export compliance, copyright holder, and private review-contact information.
- [ ] Select the validated build, manual release, and submit for review after
  the owner approves the final listing and release checks.

## 5. Screenshots and launch

Capture the actual shipping UI with made-up content only. Do not publish the
developer's personal drafts or desktop. Suggested shots: (1) a tidy draft with a
plain-text table; (2) search across sample drafts; (3) dark appearance with a code
snippet. Do not claim rendered tables or AI features. See the synthetic text in
`app-store/SCREENSHOT-CONTENT.md`.

Check Apple's current Mac screenshot dimensions before capture. Screenshots,
signed-runtime QA, and App Store submission are required release gates, not
covered by unit tests. After approval, verify the product page and price, release
manually, then add the real App Store link to README/support. Remove “not yet
available” wording only when customers can actually purchase it.

## Official references

- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [Set an app price](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [GitHub Actions security](https://docs.github.com/en/actions/reference/security/secure-use)
