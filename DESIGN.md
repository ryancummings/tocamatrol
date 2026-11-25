# Design System — Ink & Pop (Comic-Book Utility)

## Direction & Anti-Reference
Tocamatrol replaces its previous muted dark-charcoal/amber Console aesthetic (`#0A0805`, `#15120E`, `//` monospace kickers, low-contrast dusty keycaps) with **Ink & Pop**: an energetic, tactile comic-book visual world inspired by Silver-Age Pop Art, crisp Bristol-board print panels, and arcade snap-action switches.

- **Mood:** Kinetic, high-contrast, joyful, razor-legible.
- **Dual First-Class Appearances:** Follows iOS System appearance or user override (`Auto` / `Paper` / `Midnight` in Settings) on iOS, and `prefers-color-scheme` (`Bright Bristol` Light / `Dark Electric Comic` Dark) on the web flasher.

## Color Architecture

### iOS Bright Newsprint (Light)
- `ground`: `#FFF6DF` (warm newsprint cream)
- `well`: `#F4E6C3` (halftone paper well)
- `surface`: `#FFFDF7` (crisp Bristol board card)
- `raised`: `#FFE885` (sunburst elevated fill)
- `inkBorder` / `inkShadow`: `#151311` (bold India-ink outlines, 2–2.5pt stroke, hard 2–3pt offset drop block)
- `hairline`: `#D8C7A0` (internal row/table dividers)
- `text`: `#151311` | `muted`: `#473F35` | `dim`: `#655B4E` (all >= 5.5:1 AA on `#FFFDF7` / `#FFF6DF`)
- `tint`: `#0F52EB` (Hero Cobalt Blue for navigation actions, links, focus rings, sliders)
- `popYellow`: `#FFD21F` paired with `#151311` ink text (primary CTAs, active segments, resize grip, narrator stamps)
- `highlightLabel`: `#A83200` (deep Burnt Comic Orange for readouts and numeric values on Bristol/paper)
- `green`: `#0B8A40` | `red`: `#D11B1B` | `halftone`: `#151311` @ 5.5% alpha

### Web Bright Bristol-Sky (Light)
- `ground`: `#EEF4FF` (cool comic newsprint / cyan-tinted Bristol sheet)
- `well`: `#DCE8FF` (blueprint inset band)
- `surface`: `#FFFFFF` (crisp comic panel white)
- `raised`: `#FFE885` (sunburst elevated fill)
- `inkBorder` / `inkShadow`: `#151311` | `hairline`: `#B8CCF0`
- `text`: `#151311` | `muted`: `#403B36` | `dim`: `#575049`
- `accent`: `#1248CF` | `accent-label`: `#9E2D00` | `yellow`: `#FFD21F` (`pop-ink`: `#151311`)
- `cyan`: `#0FC5DE` | `vermilion`: `#D92B21` | `ok`: `#0A6B31` | `bad`: `#BF1919` | `halftone`: `rgba(18, 72, 207, 0.08)`

### Dark Electric Comic (iOS & Web Dark)
- `ground`: `#10152B` (midnight comic indigo — never brownish charcoal)
- `well`: `#0A0E1F` (deep night panel well)
- `surface`: `#182042` (rich cobalt card)
- `raised`: `#243061` (elevated indigo surface)
- `inkBorder`: `#7A93E6` (crisp electric comic keyline)
- `inkShadow`: `#050712` (deep solid offset drop block)
- `hairline`: `#2D3B73`
- `text`: `#F7F5EE` | `muted`: `#B7C4E6` | `dim`: `#8899C4` (`#93A4D1` web)
- `tint` / `accent`: `#38E4FF` (Electric Cyan)
- `popYellow`: `#FFD21F` paired with `#151311` / `#12100E` ink text
- `highlightLabel` / `accent-label`: `#FFD21F` (Sunburst Yellow)
- `green` / `ok`: `#2EE87A` | `red` / `bad`: `#FF4D6A` (`#FF5C77` web) | `halftone`: `#56A8FF` @ 9% alpha

## 9 Adaptive Pop-Art Keycap Styles (`KeyStyle`)
Raw `ButtonAppearance.Tint` keys remain backwards-compatible (`sand`, `amber`, `rust`, `rose`, `violet`, `blue`, `teal`, `green`, `graphite`) with WCAG AA-verified label contrast across both themes:
- `sand`: Sunburst Yellow (`#FFE45E` -> `#FFD21F`, ink `#151311`; Dark `#F5CE2E` -> `#DAA908`, ink `#12100E`)
- `amber`: Comic Tangerine (`#FF9E3D` -> `#FF7315`, ink `#151311`; Dark `#FF9429` -> `#E66300`, ink `#12100E`)
- `rust`: Hero Vermilion (`#DF2920` -> `#C41D15`, `#FFFFFF`; Dark `#DE2B2B` -> `#BF1E2E`, `#FFFFFF`)
- `rose`: Bubblegum Magenta (`#CC1B6E` -> `#AD135B`, `#FFFFFF`; Dark `#D11B76` -> `#B31263`, `#FFFFFF`)
- `violet`: Cosmic Purple (`#6F38E6` -> `#5823C9`, `#FFFFFF`; Dark `#6D36E8` -> `#5622CC`, `#FFFFFF`)
- `blue`: Hero Cobalt (`#1A5BE0` -> `#1145B8`, `#FFFFFF`; Dark `#1D5CE0` -> `#1448BA`, `#FFFFFF`)
- `teal`: Electric Cyan (`#45E3F7` -> `#0FC5DE`, ink `#151311`; Dark `#33DCF2` -> `#0BB2C9`, ink `#10131F`)
- `green`: Power Emerald (`#4FE36E` -> `#22C447`, ink `#151311`; Dark `#42DB63` -> `#19B03C`, ink `#10131F`)
- `graphite`: Crisp Bristol / Midnight Key (`#FFFFFF` -> `#EFE8D6`, ink `#151311`; Dark `#2E3B70` -> `#202A52`, `#F7F5EE`)

## Typography, Borders & Motion
- **iOS Typography:** SF Pro Rounded Heavy/Black for panel/readout/badge headlines; Bold SF Pro/Rounded/Serif/Mono for macro keycap labels (so 8×6 grids stay sharp); Monospaced reserved for real data (HID chords, signal dBm, firmware addresses, timing).
- **Web Typography:** Self-hosted `Archivo Black` display face, `Rubik` body/UI sans, and `JetBrains Mono` technical metadata.
- **No `//` Eyebrows:** Headings carry their own weight without decorative `// SECTION` kickers above them.
- **Comic Depth & Press-Slam Physics:** Panels carry solid 2–2.5pt ink outlines and hard offset shadows (`radius: 0`, offset `2–4px`). Interactive keys and tiles slam flush onto their shadow offset (`+3pt X, +4pt Y`) on touch-down within `0.06s`, respecting `Reduce Motion`.
