#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${MOSAIC_BUILD_DIR:-$ROOT/desktop/macos/build}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
MOSAIC_BUILD_DIR="$OUT" "$ROOT/desktop/macos/build.sh"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -module-cache-path "$OUT/modules" -swift-version 5 -parse-as-library -sdk "$SDK" \
  -import-objc-header "$ROOT/mobile/ios/Mosaic/GeometryBridge.h" \
  "$ROOT/desktop/macos/Mosaic/Collage.swift" "$ROOT/desktop/macos/Tests/CollageTests.swift" \
  "$OUT/objects/Geometry.o" "$OUT/objects/Bridge.o" -Xlinker -lc++ -o "$OUT/CollageTests"
"$OUT/CollageTests"
