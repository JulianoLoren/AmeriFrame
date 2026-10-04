# Mosaic native apps

Two fully native, offline clients for the existing Mosaic photo collage studio:

- **iOS 17+**: SwiftUI, PhotosPicker, Core Graphics/ImageIO, system share sheet.
- **Android 9+ (API 28)**: Kotlin, Jetpack Compose, Android Photo Picker, ImageDecoder/Canvas, system share sheet and document saver.
- **Shared C++17 geometry**: all 36 web layouts, linked directly through Objective-C++ and JNI. No WebView, JavaScript runtime, account, server, or network permission.

Both apps support 1–24 photos, five ratio presets and custom ratios from 1:5 to 5:1, layout categories, selection, drag-to-crop, pinch-to-zoom directly in each frame, accessible crop sliders, 100–400% zoom, reorder/remove/reset, 0–120 px frames, custom frame colors, Vietnamese/English, system/light/dark themes, and PNG/JPG exports with a 3840-pixel long edge. Preview and export share the same renderer and geometry; selection outlines are never exported.

Use **Add photos → choose ratio/layout → adjust → export**. iOS uses the share sheet to save to Files/Photos or share. Android provides both Share and Save to file. Original photos are not changed. Formats supported by the platform's image decoder can be imported, including common JPEG/PNG/HEIC images; support for WEBP/AVIF depends on the OS version.

## iOS

Open `ios/Mosaic.xcodeproj` in Xcode 16 or newer and select the **Mosaic** scheme. Choose an iPhone/iPad simulator and Run. There are no external package dependencies.

```sh
xcodebuild -project mobile/ios/Mosaic.xcodeproj -scheme Mosaic \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath /tmp/mosaic-ios-build CODE_SIGNING_ALLOWED=NO build

# Substitute a simulator name installed on your Mac (xcrun simctl list devices available).
xcodebuild -project mobile/ios/Mosaic.xcodeproj -scheme Mosaic \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -parallel-testing-enabled NO -derivedDataPath /tmp/mosaic-ios-build CODE_SIGNING_ALLOWED=NO test
```

If `xcodebuild` selects only Command Line Tools, prefix the command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

For a physical device, choose your Apple development team in Signing & Capabilities and a bundle identifier you own. The current placeholder is `com.ameriframe.mosaic`. For App Store delivery, configure signing and your App Store Connect record, then Product → Archive. Store submission is not part of the repository build.

`ios/Mosaic.xcodeproj` and the shared scheme are committed. After adding/removing source files, regenerate deterministically with `python3 mobile/scripts/generate_xcode_project.py`; keep custom build settings in that generator.

## Android

Open `mobile/android` in Android Studio, or use the committed Gradle wrapper. Prerequisites: JDK 17, Android SDK platform 36, Build Tools 35.0.0, NDK 27.2.12479018, CMake 3.22.1. Gradle 8.13, AGP 8.13.2, Kotlin 2.2.21 and Compose BOM 2025.08.01 are pinned; the wrapper distribution has a SHA-256 checksum.

Point `ANDROID_HOME` at your SDK, or create an untracked `mobile/android/local.properties` containing `sdk.dir=/absolute/path/to/Android/sdk`.

```sh
cd mobile/android
./gradlew :app:assembleDebug :app:lintDebug
# With a device/emulator connected:
./gradlew :app:connectedDebugAndroidTest
```

APK: `mobile/android/app/build/outputs/apk/debug/app-debug.apk`. Install with `adb install -r <apk-path>`. Debug APKs are locally signed for development. For store delivery, use your own application ID/signing configuration and `:app:bundleRelease`; never commit a keystore or password.

Native libraries are built for arm64-v8a, armeabi-v7a, x86 and x86_64, with 16 KB page alignment. The app has no Internet or broad storage/media permissions. The platform picker falls back to the system document picker when needed.

## Verification

From the repository root:

```sh
node --test tests/geometry.test.mjs
python3 mobile/scripts/verify_core.py
```

The second command compiles the actual C++ implementation and compares **18,144 cases** against `dist/geometry.js`: all 36 layouts, 1–24 photos, seven ratios and three border sizes. A C++17 compiler, Python 3 and Node are required. Floating-point contraction is disabled so the native split decisions match JavaScript arithmetic.

The iOS UI test also imports two photos, changes the ratio, and opens the native share sheet. Seed at least two photos into your simulator with `xcrun simctl addmedia <device-udid> tests/fixtures/photo-1.png tests/fixtures/photo-2.png` before running it. CI seeds those fixtures automatically.

Both native test suites exercise the real bridge, extreme-ratio/24-photo geometry, crop containment, reorder/remove/reset, image decode budgets, preview/export proportional agreement and real 4K PNG/JPG dimensions and pixel colors. iOS additionally checks EXIF rotation. Android instrumentation tests require an emulator/device, not a JVM-only runner.

The existing Docker deployment tests require Docker Compose; they are independent of mobile. Run `node --test tests/*.test.mjs` on a machine with Docker installed.

Before release, exercise photo picker cancel/reopen, mixed valid/invalid images, HEIC/EXIF photos, 24-photo import, drag/slider crop, reorder/remove to empty, portrait/landscape rotation, custom ratios, both languages/themes, Files save/share cancellation and actual exported images on physical devices.

## Session and memory behavior

Photos/crops are held in memory for the editing session. Android retains them across configuration changes through a ViewModel; neither app restores a session after process termination. Language/theme preferences persist. Exported files only persist where the user explicitly saves/shares them; temporary export files are removed after 24 hours on the next export. Temporary picker copies are deleted after decoding.

Imports reject files larger than 30 MB. Images are decoded off the UI thread, honoring orientation, with a 3840-pixel maximum edge and a **24-million-pixel total source budget**. Adding more photos may downsample earlier imports to stay within that budget. This keeps small collages detailed while bounding memory for 24 photos. Export resolution cannot recreate detail lost from a small or downsampled source. PNG/JPG exports are opaque raster images, not HDR assets.
