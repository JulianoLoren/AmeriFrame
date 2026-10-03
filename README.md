# Mosaic

A responsive, bilingual Vietnamese/English photo collage studio. Plain ES modules and Canvas 2D; no build or runtime dependencies.

## Native iOS and Android apps

See [mobile/README.md](mobile/README.md) for the SwiftUI iOS app and Kotlin/Jetpack Compose Android app, build instructions, and tests. Both run offline and share all 36 collage layouts through a native C++ engine.

## Native macOS and Windows apps

See [desktop/README.md](desktop/README.md) for the SwiftUI/AppKit macOS and WPF Windows apps, local builds, portable packaging, and platform tests. All four native apps share the C++ layouts. The [icon generator](assets/icons/README.md) keeps branding consistent across web and native platforms.

## Docker deployment

See [DEPLOY.md](DEPLOY.md) for Docker Compose with Cloudflare Tunnel. No host ports
are published. Add your tunnel token as a local secret file, configure the
Cloudflare route to `http://web:8080`, then run `docker compose up -d --build --wait`.

## Run without Docker

From this directory: `python -m http.server 4173 --bind 127.0.0.1 --directory dist`, then open http://127.0.0.1:4173/.

## Features

- Select or drop up to 24 JPG, PNG, WEBP or AVIF photos, up to 30 MB each. All image processing stays on the user's device.
- Five ratio presets and a custom ratio from 1:5 to 5:1.
- 36 adaptive layout families: 12 classic and 24 creative, including spiral, diamond, honeycomb, constellation, origami, and sunrays.
- Drag to crop each image, zoom 100–400%, arrow-key positioning, and reset the selected image. Bracket keys select the previous/next photo.
- White frame by default; custom colors and frame thickness. Extreme thickness is reduced when necessary to preserve all cells.
- PNG/JPG downloads with a 3840-pixel long edge. Square output is 3840 × 3840; 16:9 is 3840 × 2160. Export dimensions do not add missing detail to low-resolution source images.
- Black and white interface themes, initially following the system preference, with a persistent manual override. Theme changes do not modify photo colors or export settings.
- Language preference is stored locally. Photos are not persisted after refresh.
- Optional WebMCP read/configuration tools, feature-detected in supported browsers.

## Verify

`node --test tests/geometry.test.mjs`

Geometry checks cover every photo count and layout, polygon convexity/coverage, crop containment, safe borders, and proportional agreement between preview and export.

Publish the `dist` folder as a static website. `.openai/hosting.json` records the Sites deployment identity.
