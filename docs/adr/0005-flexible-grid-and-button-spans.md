# Flexible per-page grids and arbitrary button spans

Pages store an explicit `GridShape(columns, rows)` (between `2×2` and `8×6`) and each
button stores an arbitrary `ButtonSpan(columns, rows)` instead of a fixed `4×3`/`3×4` grid
and four-case `ButtonSize` enum. Pages are no longer auto-transposed on load when opened on
another device class, preserving user-chosen layouts verbatim while retaining lossless
decoding of version 1–5 libraries.

## Considered Options

- **Keep fixed 4×3 / 3×4 + 4-case enum**: simple, but wastes space on iPad once no fixed
  built-in sidebar exists and prevents multi-column banners or dense button grids.
- **Freeform pixel/coordinate canvas**: flexible, but breaks clean alignment and resize
  snapping across iPhone and iPad screen aspect ratios.

## Consequences

- Both iPhone and iPad render full-width user pages using the same grid engine.
- Version 6 JSON encodes `span: {"columns", "rows"}` while still reading legacy `slots`
  (v1), `size` strings (v2–v5), and macro-level `appearance` (v4).
