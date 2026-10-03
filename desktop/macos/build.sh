#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${MOSAIC_BUILD_DIR:-$ROOT/desktop/macos/build}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p "$OUT/Mosaic.app/Contents/MacOS" "$OUT/Mosaic.app/Contents/Resources" "$OUT/objects"
ARCH="${MOSAIC_ARCH:-$(uname -m)}"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun clang++ -std=c++17 -O2 -ffp-contract=off -arch "$ARCH" -mmacosx-version-min=13.0 -isysroot "$SDK" -c "$ROOT/mobile/core/Geometry.cpp" -o "$OUT/objects/Geometry.o"
xcrun clang++ -std=c++17 -O2 -fobjc-arc -arch "$ARCH" -mmacosx-version-min=13.0 -isysroot "$SDK" -c "$ROOT/mobile/ios/Mosaic/GeometryBridge.mm" -o "$OUT/objects/Bridge.o"
xcrun swiftc -module-cache-path "$OUT/modules" -swift-version 5 -O -target "$ARCH-apple-macosx13.0" -sdk "$SDK" \
  -import-objc-header "$ROOT/mobile/ios/Mosaic/GeometryBridge.h" \
  "$ROOT"/desktop/macos/Mosaic/*.swift "$OUT/objects/Geometry.o" "$OUT/objects/Bridge.o" \
  -Xlinker -lc++ -o "$OUT/Mosaic.app/Contents/MacOS/Mosaic"
cp "$ROOT/desktop/macos/Mosaic/Info.plist" "$OUT/Mosaic.app/Contents/Info.plist"
cp "$ROOT/desktop/macos/Mosaic/AppIcon.icns" "$OUT/Mosaic.app/Contents/Resources/"
cp "$ROOT/mobile/ios/Mosaic/PrivacyInfo.xcprivacy" "$OUT/Mosaic.app/Contents/Resources/"
codesign --force --sign - "$OUT/Mosaic.app"
echo "$OUT/Mosaic.app"
