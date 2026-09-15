#!/bin/bash
set -euo pipefail
project_path="$(cd "$(dirname "$0")/.." && pwd)"
destination="${1:-$project_path/dist}"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd)"
cd "$project_path"
export CLANG_MODULE_CACHE_PATH="$project_path/.build/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_path/.build/modules"
swift build -c release --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
app="$destination/XM6 Studio.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/XM6Companion "$app/Contents/MacOS/XM6Companion"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Sources/XM6Companion/Assets/WH1000XM6.png "$app/Contents/Resources/WH1000XM6.png"
cp THIRD_PARTY.md "$app/Contents/Resources/THIRD_PARTY.md"
for document in Verification.md 'Feature Coverage.md'; do
    if [ -f "$document" ]; then cp "$document" "$app/Contents/Resources/"; fi
done
cp -R ThirdParty "$app/Contents/Resources/"
swift Scripts/make_icon.swift "$app/Contents/Resources/AppIcon.icns" Sources/XM6Companion/Assets/WH1000XM6.png
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$destination/XM6 Studio.zip"
printf 'Built %s\n' "$app"
