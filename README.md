# Mosaic

A responsive, bilingual Vietnamese/English photo collage studio. Plain ES modules and Canvas 2D; no build or runtime dependencies.

## Run locally

From this directory: `python -m http.server 4173 --bind 127.0.0.1 --directory dist`, then open http://127.0.0.1:4173/.

## Features

- Select or drop up to 24 JPG, PNG, WEBP or AVIF photos, up to 30 MB each. All image processing stays on the user's device.
- Five ratio presets and a custom ratio from 1:5 to 5:1.
- Twelve adaptive layout families, including brickwork, diagonal, prism and sunburst.
- Drag to crop each image, zoom 100–400%, arrow-key positioning, and reset the selected image. Bracket keys select the previous/next photo.
- White frame by default; custom colors and frame thickness. Extreme thickness is reduced when necessary to preserve all cells.
- PNG/JPG downloads with a 3840-pixel long edge. Square output is 3840 × 3840; 16:9 is 3840 × 2160. Export dimensions do not add missing detail to low-resolution source images.
- Language preference is stored locally. Photos are not persisted after refresh.
- Optional WebMCP read/configuration tools, feature-detected in supported browsers.

## Verify

`node --test tests/geometry.test.mjs`

Geometry checks cover every photo count and layout, polygon convexity/coverage, crop containment, safe borders, and proportional agreement between preview and export.

Publish the `dist` folder as a static website. `.openai/hosting.json` records the Sites deployment identity.
