#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
bash -n scripts/build.sh scripts/build-appstore.sh scripts/test.sh
plutil -lint Resources/Info.plist Resources/Jotwisp.entitlements Resources/PrivacyInfo.xcprivacy Jotwisp.xcodeproj/project.pbxproj
swift scripts/check-metadata.swift
for path in LICENSE README.md docs/PRIVACY.md docs/SUPPORT.md docs/RELEASING.md Resources/AppIcon.icns; do
    test -s "$path" || { printf 'Missing release file: %s\n' "$path" >&2; exit 1; }
done
printf 'Local release-file checks passed. This does not verify signing, live URLs, screenshots, or store readiness.\n'
