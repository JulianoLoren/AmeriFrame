# Working on Mosaic

## Product and structure
- Mosaic is a private, offline photo collage studio. Do not upload photos, add analytics, or introduce a server requirement.
- `dist/` contains the dependency-free web app; these are maintained source files, not disposable build output.
- `mobile/ios/` contains the native SwiftUI app. `mobile/android/` contains the native Kotlin/Jetpack Compose app.
- `mobile/core/` contains platform-independent C++ layout geometry shared by both apps. Keep its behavior aligned with `dist/geometry.js`.
- Preserve Vietnamese and English, all 36 layout families, 1–24 photos, crop containment, safe borders, and a 3840-pixel export long edge.

## Implementation
- Use platform photo pickers and share sheets. Do not request broad photo/storage access when a system picker suffices.
- Keep image decoding and export off the UI thread. Bound decoded image memory, honor EXIF orientation, and report unreadable files without losing valid photos.
- Preview and export must use the same geometry and crop calculations. Theme changes must never change exported colors.
- Keep source, build configuration, and instructions in git. Never commit local SDK paths, signing credentials, build products, user photos, or secrets.
- Do not replace native UI with a WebView or cross-platform JavaScript framework.

## Verification and delivery
- Run `node --test tests/*.test.mjs` for web regression checks.
- Run `python3 mobile/scripts/verify_core.py` after geometry changes; it compares native output against the web implementation.
- Build both mobile targets for changes affecting them. See `mobile/README.md` for exact commands and prerequisites.
- Exercise import, crop, layout/ratio changes, reorder/remove, and PNG/JPG export on a simulator or device when available. Report missing tooling or unverified checks honestly.
- Commit coherent, verified milestones as requested by the owner. Use professional imperative Conventional Commit messages, e.g. `feat(ios): add native collage editor`. Do not include unrelated existing changes.
