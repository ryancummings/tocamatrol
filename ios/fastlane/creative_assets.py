#!/usr/bin/env python3
"""Render the iOS 27 App Store creative assets in the Ink & Pop poster style.

- header_21x9.png (3840x1646): product page header. No text; the store shows the name.
- search_3x2.png (3840x2560): search results art. One short headline and the real UI.

Specs: developer.apple.com/help/app-store-connect/reference/app-information/
creative-assets-specifications. PNG, sRGB, no alpha; key content inside the Art Safe Area
(header 1646x661 at x1097,y493; search 2168x1030 at x836,y765). No prices, URLs or awards.

Output: ios/fastlane/creative/. `fastlane ios creative_assets` renders and places them.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from frame_posters import CHROME, DONGLE_SVG, ROOT, b64, prepare_upright_ipad  # noqa: E402

SHOTS = ROOT / "ios/fastlane/screenshots/en-US"
OUT = ROOT / "ios/fastlane/creative"
INK = "#151311"


def shot(name: str, ipad: bool, work: Path) -> str:
    device = "iPadPro13" if ipad else "iPhone17ProMax"
    src = SHOTS / f"Tocamatrol-Shots-{device}-{name}.png"
    assert src.is_file(), f"Missing {src}"
    if ipad:
        src = prepare_upright_ipad(src, work)
    return f"data:image/png;base64,{b64(src)}"


def device(img: str, x: int, y: int, w: int, ipad: bool, rotate: float = 0, z: int = 1) -> str:
    pad, radius, inner, border, offset = (
        (int(w * 0.022), int(w * 0.045), int(w * 0.03), 12, 30) if ipad
        else (int(w * 0.03), int(w * 0.14), int(w * 0.11), 10, 24)
    )
    return f"""<div class="device" style="left:{x}px; top:{y}px; width:{w}px; padding:{pad}px;
      border-radius:{radius}px; border-width:{border}px; box-shadow:{offset}px {offset + 4}px 0 0 {INK};
      transform:rotate({rotate}deg); z-index:{z};">
      <img src="{img}" style="border-radius:{inner}px" /></div>"""


def dongle(x: int, y: int, w: int, rotate: float, z: int = 3) -> str:
    return f"""<div style="position:absolute; left:{x}px; top:{y}px; width:{w}px;
      transform:rotate({rotate}deg); z-index:{z};">{DONGLE_SVG}</div>"""


def page(width: int, height: int, body: str, bg1: str, bg2: str) -> str:
    fonts = ROOT / "web/src/fonts"
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
@font-face {{ font-family:"Archivo Black"; src:url("data:font/woff2;base64,{b64(fonts / 'archivo-black-400-latin.woff2')}") format("woff2"); }}
@font-face {{ font-family:"Rubik"; font-weight:400 700; src:url("data:font/woff2;base64,{b64(fonts / 'rubik-latin.woff2')}") format("woff2"); }}
* {{ box-sizing:border-box; margin:0; padding:0; }}
html, body {{ width:{width}px; height:{height}px; overflow:hidden; font-family:"Rubik", sans-serif;
  background:linear-gradient(165deg, {bg2} 0%, {bg1} 100%); position:relative; }}
.rays {{ position:absolute; inset:-40%; background:repeating-conic-gradient(from 0deg at 50% 50%,
  rgba(255,255,255,0.22) 0deg 7deg, transparent 7deg 18deg); }}
.dots {{ position:absolute; inset:0;
  background-image:radial-gradient(rgba(21,19,17,0.13) 6px, transparent 6px),
                   radial-gradient(rgba(21,19,17,0.13) 6px, transparent 6px);
  background-size:56px 56px; background-position:0 0, 28px 28px; }}
.device {{ position:absolute; background:#1C1A17; border:solid {INK}; }}
.device img {{ display:block; width:100%; border:4px solid #090807; }}
.dongle {{ display:block; width:100%; }}
.card {{ position:absolute; background:#FFFDF7; border:12px solid {INK}; border-radius:56px;
  box-shadow:28px 32px 0 0 {INK}; }}
h1 {{ font-family:"Archivo Black", sans-serif; font-weight:400; text-transform:uppercase;
  color:{INK}; letter-spacing:-0.02em; line-height:1.0; }}
.sub {{ font-weight:600; color:#36302A; }}
.chips {{ display:flex; flex-wrap:wrap; gap:30px; }}
.chip {{ font-family:"Archivo Black", sans-serif; color:{INK}; background:#FFFDF7; border:8px solid {INK};
  border-radius:999px; box-shadow:10px 12px 0 0 {INK}; }}
</style></head><body><div class="rays"></div><div class="dots"></div>{body}</body></html>"""


def header(work: Path) -> tuple[int, int, str]:
    # The macro pad on iPad in the middle of the safe area, the macro editor on iPhone to the left,
    # and the dongle to the right, so the whole setup reads at a glance. Devices bleed off the
    # bottom, where the store lays its name, icon and Get button.
    w, h = 3840, 1646
    ipad_w = 1560
    body = (
        device(shot("06_MacroEditor", False, work), 520, 330, 560, False, rotate=-7, z=1)
        + device(shot("01_MacroPad", True, work), (w - ipad_w) // 2 - 80, 300, ipad_w, True, z=2)
        + dongle(2780, 620, 960, rotate=-10)
    )
    return w, h, page(w, h, body, "#FFD83D", "#FFF2A6")


def search(work: Path) -> tuple[int, int, str]:
    # Purpose on the left, the real macro pad and the dongle it drives on the right.
    w, h = 3840, 2560
    chips = "".join(
        f'<span class="chip" style="font-size:64px; padding:22px 52px">{c}</span>'
        for c in ("Macro pad", "Trackpad", "No PC software")
    )
    body = f"""
    <div class="card" style="left:300px; top:520px; width:2000px; padding:110px 120px 120px;">
      <h1 style="font-size:190px">A macro pad for any PC</h1>
      <p class="sub" style="font-size:74px; line-height:1.25; margin-top:56px">
        Custom keys and a trackpad on your iPhone or iPad, through one small USB dongle.</p>
    </div>
    <div class="chips" style="position:absolute; left:320px; top:1640px; width:1900px; z-index:4">{chips}</div>
    {device(shot("01_MacroPad", False, work), 2560, 180, 880, False, rotate=4, z=1)}
    {dongle(1380, 1930, 1060, rotate=-8)}
    """
    return w, h, page(w, h, body, "#FFD83D", "#FFF2A6")


def render(name: str, build, work: Path) -> Path:
    w, h, doc = build(work)
    html_path = work / f"{name}.html"
    raw = work / f"{name}.raw.png"
    html_path.write_text(doc, encoding="utf-8")
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
         f"--window-size={w},{h}", f"--screenshot={raw}", html_path.as_uri()],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    out = OUT / f"{name}.png"
    # Apple rejects alpha: flatten, pin exact pixels, sRGB.
    subprocess.run(["magick", str(raw), "-background", "white", "-alpha", "remove", "-alpha", "off",
                    "-extent", f"{w}x{h}", "-colorspace", "sRGB", str(out)], check=True)
    ident = subprocess.check_output(
        ["magick", "identify", "-format", "%wx%h %[channels]", str(out)], text=True).strip()
    assert ident.startswith(f"{w}x{h} srgb") and "srgba" not in ident, f"Unexpected format: {ident}"
    print(f"{out}: {ident}")
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="toca-creative-") as tmp:
        work = Path(tmp)
        render("header_21x9", header, work)
        render("search_3x2", search, work)


if __name__ == "__main__":
    main()
