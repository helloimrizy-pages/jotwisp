#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release --disable-sandbox --cache-path .build/cache
app="${JOTWISP_BUILD_APP:-build/Jotwisp.app}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Jotwisp "$app/Contents/MacOS/Jotwisp"
cp Resources/Info.plist "$app/Contents/Info.plist"
icon_source="Resources/Branding/jotwisp-logo-concept-v1.png"
if [ ! -f build/AppIcon.icns ] || [ scripts/make-icon.swift -nt build/AppIcon.icns ] || [ "$icon_source" -nt build/AppIcon.icns ]; then
    mkdir -p build/AppIcon.iconset
    swift scripts/make-icon.swift "$icon_source" build/AppIcon.iconset
fi
cp build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp Resources/PrivacyInfo.xcprivacy "$app/Contents/Resources/PrivacyInfo.xcprivacy"
cp docs/PRIVACY.md docs/SUPPORT.md "$app/Contents/Resources/"
cp LICENSE "$app/Contents/Resources/LICENSE.md"
signing_identity="${TEXTDUMP_SIGNING_IDENTITY:--}"
codesign --force --sign "$signing_identity" "$app"
codesign --verify --strict "$app"
if [ "$signing_identity" = "-" ]; then
    printf 'Note: ad-hoc builds can invalidate Accessibility grants after code changes. Remove and re-add this app in Accessibility if needed.\n'
fi
printf 'Built %s\n' "$app"
