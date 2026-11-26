#!/usr/bin/env python3
"""Render the iOS 27 App Store creative assets from the how-it-works promo scene.

Both are stills of tools/promo_video/promo.html (the same scene as the web promo video),
taken mid-macro: keystroke packets in flight from the phone to the dongle while the PC's
terminal types `git status`.

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
from frame_posters import CHROME, ROOT  # noqa: E402

PROMO = ROOT / "tools/promo_video/promo.html"
OUT = ROOT / "ios/fastlane/creative"
MOMENT = 4.6  # seconds into the promo loop

# name -> (promo format, width, height); the page renders at half size, Chrome doubles it.
ASSETS = {
    "header_21x9": ("header", 3840, 1646),
    "search_3x2": ("search", 3840, 2560),
}


def render(name: str, fmt: str, w: int, h: int, work: Path) -> Path:
    raw = work / f"{name}.raw.png"
    url = f"{PROMO.as_uri()}?capture&format={fmt}&t={MOMENT}"
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
         "--force-device-scale-factor=2", "--virtual-time-budget=4000",
         f"--window-size={w // 2},{-(-h // 2)}", f"--screenshot={raw}", url],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    out = OUT / f"{name}.png"
    # Apple rejects alpha: flatten, pin exact pixels (crops the odd row), sRGB.
    subprocess.run(["magick", str(raw), "-background", "white", "-alpha", "remove", "-alpha", "off",
                    "-gravity", "north", "-extent", f"{w}x{h}", "-colorspace", "sRGB", str(out)], check=True)
    ident = subprocess.check_output(
        ["magick", "identify", "-format", "%wx%h %[channels]", str(out)], text=True).strip()
    assert ident.startswith(f"{w}x{h} srgb") and "srgba" not in ident, f"Unexpected format: {ident}"
    print(f"{out}: {ident}")
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="toca-creative-") as tmp:
        for name, (fmt, w, h) in ASSETS.items():
            render(name, fmt, w, h, Path(tmp))


if __name__ == "__main__":
    main()
