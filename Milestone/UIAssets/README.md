# UI Assets Directory

This folder is the design system surface for Milestone.

## What lives here
- Color tokens (`UIAssetColors`)
- Typography tokens (`UIAssetTextStyle`)
- Reusable control primitives (buttons, toggles, text fields, dropdowns)
- A live preview catalog (`UIAssetsCatalogView`)

## How to add new assets
1. Add or update tokens first (colors, text styles, spacing, corner radius).
2. Add reusable component primitives second.
3. Add a visual example to `UIAssetsCatalogView`.
4. Replace duplicated styling in app screens by using these primitives.

## Naming
- Prefix new design system types with `UIAsset...` to keep usage clear.
- Keep tokens semantic (`primary`, `subtitle`, `destructive`) instead of screen-specific names.
