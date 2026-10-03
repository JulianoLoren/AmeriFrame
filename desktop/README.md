# Native desktop apps

Mosaic has a SwiftUI/AppKit macOS app and a C#/WPF Windows app. Both use the existing C++ geometry engine, run offline, and include all 36 layouts, 1–24 photos, VI/EN, light/dark themes, ratio presets/custom ratios, drag-to-crop, zoom, reorder/remove, colored frames and PNG/JPG export with a 3840 px long edge. Native file dialogs and drag/drop handle import; Cmd/Ctrl+O imports and Cmd/Ctrl+S exports.

Files are limited to 30 MB each. Sources are downsampled to a shared 24-million-pixel budget; EXIF orientation is honored. Supported input formats depend on installed OS image codecs (PNG and JPEG are baseline; HEIC/WebP/AVIF availability varies). Photos and edit sessions are held in memory only; closing the app discards the session. Theme and language persist locally.

## macOS 13 or later

Install Xcode with its macOS SDK. No external packages or project generator are required:

```sh
desktop/macos/test.sh
open desktop/macos/build/Mosaic.app
```

`build.sh` builds without tests. `MOSAIC_BUILD_DIR=/absolute/path` changes the output location. The default architecture matches the build machine; use `MOSAIC_ARCH=x86_64` for Intel or `MOSAIC_ARCH=arm64` for Apple Silicon. `DEVELOPER_DIR` can select another Xcode installation. Tests cover native import, EXIF, bounded decoding, crop/layout geometry, reorder/remove and the actual colors/dimensions/orientation of PNG and JPEG exports.

The bundle is ad-hoc signed for local development. Public distribution requires the owner's Developer ID signing and Apple notarization; no signing credentials are included.

## Windows x64

Build on Windows with the .NET 10 SDK, Visual Studio Build Tools with **Desktop development with C++**, and CMake 3.22 or later on PATH:

```powershell
./desktop/windows/build.ps1
./desktop/windows/build/Mosaic/Mosaic.exe
```

The script builds the native geometry DLL with MSVC, runs the WPF rendering tests on Windows, and publishes a self-contained portable app. Copy the **entire** `build/Mosaic` folder; recipients do not need a separate .NET installation. `-Output C:/path` changes the output directory. `-SkipTests` is available for packaging after tests have already passed. The app targets Windows x64 with a supported .NET 10 Windows version. It is not Authenticode signed and has no installer yet.

For cross-compilation, supply an x64 Windows build of `MosaicGeometry.dll`:

```sh
dotnet build desktop/windows/Tests/Mosaic.Tests.csproj -c Release -p:MosaicNativeLibrary=/absolute/path/MosaicGeometry.dll
dotnet publish desktop/windows/Mosaic/Mosaic.csproj -c Release -r win-x64 --self-contained true -p:MosaicNativeLibrary=/absolute/path/MosaicGeometry.dll -o /absolute/path/Mosaic
```

`EnableWindowsTargeting` permits compilation on macOS/Linux, but **WPF execution and rendering tests require Windows**. The desktop GitHub Actions workflow runs those tests on `windows-latest` and uploads the portable app; it also builds/tests and uploads macOS. CI must pass before treating Windows runtime behavior as verified. Local development verification so far: macOS build and native tests passed; Windows cross-build passed, Windows runtime tests await a Windows host.

## Shared assets and checks

Icons for web and all four native platforms come from [../assets/icons/generate.py](../assets/icons/generate.py). Run `python3 assets/icons/generate.py` to regenerate them.

`python3 desktop/scripts/verify_bridge.py` checks the Windows C ABI on a POSIX host: catalog UTF-8, all counts/layouts at extreme ratios, invalid input and output-buffer guards. `python3 mobile/scripts/verify_core.py` remains the full C++/web geometry parity check.
