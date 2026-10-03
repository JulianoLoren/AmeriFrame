# Native mobile changes

Follow the root `AGENTS.md` and `README.md` in this directory.

- Keep SwiftUI and Compose implementations aligned in features, language, validation, and crop semantics.
- `core/Geometry.cpp` is shared production code. Preserve the order of floating-point operations and `-ffp-contract=off`; tiny tie-breaking changes can select different cells.
- Preview geometry must be computed at export dimensions then scaled to the view. Do not derive layout ratios from rounded view pixels.
- Keep photo decoding/export on background executors. Never retain unbounded originals or persist picker permissions unnecessarily.
- Do not recycle a bitmap while Compose might still draw it. Do recycle private export bitmaps after encoding.
- Keep Android FileProvider access limited to the export cache directory. No Internet or broad storage permission is needed.
- Xcode project source of truth: `scripts/generate_xcode_project.py`. Commit generated project changes too.
- Run the native/web comparison and relevant platform tests. Use real PNG/JPG export assertions, not mocks of the renderer.
- Build and verify coherent milestones before committing. Document any unavailable simulator/device checks.
