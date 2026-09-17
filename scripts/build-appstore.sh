#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p build/AppIcon.iconset
if [ ! -f Resources/AppIcon.icns ] || [ Resources/Branding/jotwisp-logo-concept-v1.png -nt Resources/AppIcon.icns ] || [ scripts/make-icon.swift -nt Resources/AppIcon.icns ]; then
    swift scripts/make-icon.swift Resources/Branding/jotwisp-logo-concept-v1.png build/AppIcon.iconset
    cp build/AppIcon.icns Resources/AppIcon.icns
fi
mode="${1:---check}"
case "$mode" in
    --check)
        # Compile both Mac architectures without using an Apple account or uploading.
        xcodebuild -quiet -project Jotwisp.xcodeproj -scheme Jotwisp -configuration Release \
            -derivedDataPath build/AppStoreCheck -destination 'generic/platform=macOS' \
            CODE_SIGNING_ALLOWED=NO build
        ;;
    --archive)
        # Requires a valid Apple team and local signing setup. Does not upload.
        xcodebuild -quiet -project Jotwisp.xcodeproj -scheme Jotwisp -configuration Release \
            -derivedDataPath build/AppStoreArchive -destination 'generic/platform=macOS' \
            -archivePath build/Jotwisp.xcarchive archive
        ;;
    *) printf 'Usage: bash scripts/build-appstore.sh [--check|--archive]\n' >&2; exit 2 ;;
esac
