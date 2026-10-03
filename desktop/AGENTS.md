# Native desktop clients

Follow the root AGENTS.md. macOS uses SwiftUI/AppKit; Windows uses WPF and a C ABI bridge to the existing C++ geometry. Do not introduce a WebView.

- Keep the same 36 layouts, VI/EN labels, ratio/crop rules, 24-photo/30 MB limits and 4K exports as mobile.
- Use native file dialogs, keyboard-accessible controls, background decoding/export and a bounded source pixel budget. Preserve EXIF orientation.
- Preview/export share rendering and geometry; never export selection outlines.
- Keep signing identities, SDK caches, user preferences and build output outside git.
- Icon source/generator: `assets/icons/generate.py`; regenerate platform assets together.
- Follow `desktop/README.md` for builds and platform tests. A cross-build is not proof that Windows runtime tests passed: report that distinction.
- Commit verified, coherent milestones with professional Conventional Commit messages.
