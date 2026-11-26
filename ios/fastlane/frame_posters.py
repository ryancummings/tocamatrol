#!/usr/bin/env python3
"""Render 14 Ink & Pop comic-book App Store posters (7 iPhone 6.9" + 7 iPad 13") via Chrome CDP.

Slides with no screenshot name draw an illustrated dongle instead of a framed screenshot.
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import socket
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SLIDES = [
    ("01", "MacroPad", "01_MacroPad", "CUSTOM MACRO PAD",
     "Resize, color, and arrange buttons for any workflow", "#FFD83D", "#FFF2A6"),
    ("02", "Trackpad", "10_Trackpad", "MAGIC TRACKPAD MODE",
     "Smooth pointer, two-finger scroll, tap and drag", "#45E3F7", "#B8F7FF"),
    ("03", "PageEditor", "05_PageEditor", "BUILD YOUR OWN GRID",
     "Drag to reorder and stretch keys up to 8×6", "#FF7AC3", "#FFC7E6"),
    ("04", "MacroEditor", "06_MacroEditor", "MULTI-STEP MACROS",
     "Type text, fire shortcuts, and time every pause", "#4FE36E", "#B8F8C6"),
    ("05", "Workspace", "02_WorkspacePage", "PAGES FOR EVERY APP",
     "Switch layouts in a tap — zero PC software", "#FF9E3D", "#FFD6AA"),
    ("06", "Connections", "08_Connections", "ZERO-DRIVER USB DONGLE",
     "Bonded BLE to any Mac, Windows, or Linux PC", "#5AA8FF", "#BFE0FF"),
    ("07", "Hardware", None, "REQUIRES A USB DONGLE",
     "Tocamatrol talks to your PC through a small ESP32-S3 stick", "#B98CFF", "#E3D2FF"),
]

FLASHER_URL = "ryancummings.github.io/tocamatrol"

# LilyGO T-Dongle-S3 (boards.json "recommended"), drawn flat in the poster's ink style.
# The screen shows what status_display.cpp draws when connected: 160x80 LCD, rotation 3.
DONGLE_SVG = """
<svg class="dongle" viewBox="0 0 1040 400" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(18 22)">
    <!-- offset ink shadow -->
    <g fill="#151311">
      <rect x="20" y="118" width="230" height="164" rx="10"/>
      <rect x="210" y="40" width="780" height="320" rx="62"/>
    </g>
  </g>
  <!-- USB-A plug -->
  <rect x="20" y="118" width="230" height="164" rx="10" fill="#D9DDE2" stroke="#151311" stroke-width="10"/>
  <rect x="20" y="118" width="230" height="40" rx="8" fill="#F4F6F8"/>
  <rect x="20" y="118" width="230" height="164" rx="10" fill="none" stroke="#151311" stroke-width="10"/>
  <rect x="62" y="172" width="44" height="30" rx="4" fill="#151311"/>
  <rect x="150" y="172" width="44" height="30" rx="4" fill="#151311"/>
  <rect x="44" y="226" width="186" height="34" rx="6" fill="#B8BEC6" stroke="#151311" stroke-width="6"/>
  <!-- body -->
  <rect x="210" y="40" width="780" height="320" rx="62" fill="#2B2724" stroke="#151311" stroke-width="10"/>
  <rect x="232" y="60" width="736" height="72" rx="40" fill="#3E3934"/>
  <!-- BOOT button on the top edge -->
  <rect x="840" y="16" width="76" height="34" rx="10" fill="#FFD83D" stroke="#151311" stroke-width="8"/>
  <!-- TF card slot at the far end -->
  <rect x="972" y="150" width="30" height="100" rx="8" fill="#151311"/>
  <!-- LCD bezel and screen -->
  <rect x="340" y="88" width="560" height="224" rx="26" fill="#0B0A09" stroke="#151311" stroke-width="8"/>
  <rect x="372" y="108" width="496" height="184" rx="10" fill="#000"/>
  <rect x="372" y="108" width="496" height="184" rx="10" fill="url(#glass)"/>
  <text x="396" y="182" fill="#5ABE6E" font-family="Menlo, monospace" font-weight="700" font-size="56">Connected</text>
  <text x="396" y="268" fill="#8A8A8A" font-family="Menlo, monospace" font-size="27">Tocamatrol 566D  v1.0</text>
  <!-- status LED -->
  <circle cx="290" cy="300" r="13" fill="#4FE36E" stroke="#151311" stroke-width="5"/>
  <defs>
    <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.10"/>
      <stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
  </defs>
</svg>
"""


def dongle_html(is_ipad: bool) -> str:
    steps = [
        ("1", "BUY", "An ESP32-S3 USB dongle, such as the LilyGO T-Dongle-S3, or a similar board"),
        ("2", "FLASH", f"Free firmware from Chrome or Edge at {FLASHER_URL}"),
        ("3", "PAIR", "Plug it into any PC, then pair it in the app"),
    ]
    rows = "".join(
        f'<div class="step"><div class="num">{n}</div><div class="txt">'
        f"<b>{html.escape(t)}</b><span>{html.escape(d)}</span></div></div>"
        for n, t, d in steps
    )
    return f"""
    <div class="hardware">
      <div class="tag">LILYGO T-DONGLE-S3 SHOWN</div>
      {DONGLE_SVG}
      <div class="steps">{rows}</div>
      <div class="note">Sold separately. Other ESP32-S3 boards work too. Classic ESP32, S2, C3 and C6 do not.</div>
    </div>
    """


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return int(s.getsockname()[1])


def prepare_upright_ipad(ipad_src: Path, work_dir: Path) -> Path:
    dims = subprocess.check_output(
        ["magick", "identify", "-format", "%w %h", str(ipad_src)], text=True
    ).strip().split()
    width, height = int(dims[0]), int(dims[1])
    if height > width:
        upright = work_dir / ipad_src.name
        subprocess.run(["magick", str(ipad_src), "-rotate", "-90", str(upright)], check=True)
        return upright
    return ipad_src


def make_html(kind: str, shot_b64: str | None, title: str, subtitle: str, bg1: str, bg2: str,
              archivo_b64: str, rubik_b64: str) -> str:
    is_ipad = kind == "ipad"
    width, height = (2064, 2752) if is_ipad else (1320, 2868)
    title_size = 92 if is_ipad else 78
    sub_size = 44 if is_ipad else 38
    banner_pad = "48px 58px" if is_ipad else "38px 46px"
    stage_css = (
        "padding: 0 64px; justify-content: center; gap: 88px;"
        if is_ipad
        else "padding: 84px 64px 0; justify-content: flex-start;"
    )
    device_css = (
        """
        width: 1860px;
        padding: 38px;
        border-radius: 76px;
        border: 10px solid #151311;
        background: #1C1A17;
        box-shadow: 24px 28px 0 0 #151311;
        """
        if is_ipad
        else """
        width: 1030px;
        padding: 26px;
        border-radius: 138px;
        border: 10px solid #151311;
        background: #1C1A17;
        box-shadow: 22px 26px 0 0 #151311;
        margin-top: 56px;
        """
    )
    screen_radius = "44px" if is_ipad else "112px"
    device = (
        dongle_html(is_ipad)
        if shot_b64 is None
        else f'<div class="device"><img class="screen" src="data:image/png;base64,{shot_b64}" /></div>'
    )
    hw_width = "1700px" if is_ipad else "1180px"
    hw_gap = "64px" if is_ipad else "56px"
    step_title = 64 if is_ipad else 52
    step_body = 40 if is_ipad else 34
    return f"""<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<style>
@font-face {{
  font-family: "Archivo Black";
  font-weight: 400;
  src: url("data:font/woff2;base64,{archivo_b64}") format("woff2");
}}
@font-face {{
  font-family: "Rubik";
  font-weight: 400 700;
  src: url("data:font/woff2;base64,{rubik_b64}") format("woff2");
}}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{
  width: {width}px;
  height: {height}px;
  overflow: hidden;
  font-family: "Rubik", sans-serif;
  background: linear-gradient(165deg, {bg2} 0%, {bg1} 100%);
  position: relative;
}}
.dots {{
  position: absolute;
  inset: 0;
  background-image:
    radial-gradient(rgba(21, 19, 17, 0.13) 4px, transparent 4px),
    radial-gradient(rgba(21, 19, 17, 0.13) 4px, transparent 4px);
  background-size: 38px 38px;
  background-position: 0 0, 19px 19px;
}}
.stage {{
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  {stage_css}
}}
.banner {{
  width: {"1840px" if is_ipad else "1160px"};
  background: #FFFDF7;
  border: 7px solid #151311;
  border-radius: 34px;
  padding: {banner_pad};
  box-shadow: 16px 18px 0 0 #151311;
  text-align: center;
}}
h1 {{
  font-family: "Archivo Black", sans-serif;
  font-size: {title_size}px;
  line-height: 1.04;
  letter-spacing: -0.02em;
  color: #151311;
  text-transform: uppercase;
}}
p {{
  margin-top: 18px;
  font-family: "Rubik", sans-serif;
  font-weight: 600;
  font-size: {sub_size}px;
  line-height: 1.24;
  color: #36302A;
}}
.device {{
  {device_css}
  position: relative;
  display: flex;
  justify-content: center;
  align-items: center;
}}
.hardware {{
  width: {hw_width};
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: {hw_gap};
  {"" if is_ipad else "flex: 1; justify-content: center; padding-bottom: 120px;"}
}}
.tag {{
  font-family: "Archivo Black", sans-serif;
  font-size: {sub_size - 6}px;
  letter-spacing: 0.06em;
  background: #151311;
  color: #FFFDF7;
  padding: 12px 26px;
  border-radius: 14px;
  transform: rotate(-2deg);
}}
.dongle {{
  width: {"1500px" if is_ipad else "1160px"};
  transform: rotate(-8deg);
  margin: {"10px 0 30px" if is_ipad else "0 0 10px"};
}}
.steps {{
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 30px;
}}
.step {{
  display: flex;
  align-items: center;
  gap: 34px;
  background: #FFFDF7;
  border: 7px solid #151311;
  border-radius: 30px;
  padding: 30px 38px;
  box-shadow: 12px 14px 0 0 #151311;
}}
.num {{
  flex: none;
  width: {step_title + 46}px;
  height: {step_title + 46}px;
  border-radius: 50%;
  background: {bg1};
  border: 6px solid #151311;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: "Archivo Black", sans-serif;
  font-size: {step_title}px;
  color: #151311;
}}
.txt b {{
  display: block;
  font-family: "Archivo Black", sans-serif;
  font-weight: 400;
  font-size: {step_title}px;
  line-height: 1;
  color: #151311;
}}
.txt span {{
  display: block;
  margin-top: 10px;
  font-weight: 600;
  font-size: {step_body}px;
  line-height: 1.22;
  color: #36302A;
}}
.note {{
  font-weight: 700;
  font-size: {step_body - 4}px;
  line-height: 1.25;
  color: #151311;
  text-align: center;
  padding: 0 24px;
}}
.screen {{
  width: 100%;
  display: block;
  border-radius: {screen_radius};
  border: 3px solid #090807;
}}
</style>
</head>
<body>
  <div class="dots"></div>
  <div class="stage">
    <div class="banner">
      <h1>{html.escape(title)}</h1>
      <p>{html.escape(subtitle)}</p>
    </div>
    {device}
  </div>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, default=ROOT / "ios/fastlane/screenshots/en-US")
    parser.add_argument("--out-dir", type=Path, default=ROOT / "ios/fastlane/deliver_screenshots/en-US")
    parser.add_argument("--contact-dir", type=Path, default=ROOT / "ios/fastlane/framed")
    args = parser.parse_args()

    fonts_dir = ROOT / "web/src/fonts"
    archivo_b64 = b64(fonts_dir / "archivo-black-400-latin.woff2")
    rubik_b64 = b64(fonts_dir / "rubik-latin.woff2")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.contact_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="toca-posters-") as tmp:
        tmp_dir = Path(tmp)
        html_dir = tmp_dir / "html"
        raw_render_dir = tmp_dir / "raw_render"
        upright_dir = tmp_dir / "ipad_upright"
        html_dir.mkdir()
        raw_render_dir.mkdir()
        upright_dir.mkdir()

        jobs = []
        for idx, slug, shot_name, title, subtitle, bg1, bg2 in SLIDES:
            if shot_name is None:
                iphone_src = ipad_src = None
            else:
                iphone_src = args.raw_dir / f"Tocamatrol-Shots-iPhone17ProMax-{shot_name}.png"
                ipad_raw = args.raw_dir / f"Tocamatrol-Shots-iPadPro13-{shot_name}.png"
                assert iphone_src.is_file(), f"Missing {iphone_src}"
                assert ipad_raw.is_file(), f"Missing {ipad_raw}"
                ipad_src = prepare_upright_ipad(ipad_raw, upright_dir)

            for kind, src, w, h, fname in [
                ("iphone", iphone_src, 1320, 2868, f"{idx}_iphone69_{slug}.png"),
                ("ipad", ipad_src, 2064, 2752, f"{idx}_ipad13_{slug}.png"),
            ]:
                hpath = html_dir / f"{fname}.html"
                hpath.write_text(
                    make_html(kind, b64(src) if src else None, title, subtitle, bg1, bg2, archivo_b64, rubik_b64),
                    encoding="utf-8",
                )
                jobs.append((hpath, raw_render_dir / fname, args.out_dir / fname, w, h))

        port = free_port()
        chrome_proc = subprocess.Popen(
            [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
             f"--remote-debugging-port={port}", f"--user-data-dir={tmp_dir / 'chrome'}", "about:blank"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            ws_url = None
            for _ in range(40):
                try:
                    targets = json.loads(urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list").read())
                    if targets:
                        ws_url = targets[0]["webSocketDebuggerUrl"]
                        break
                except Exception:
                    time.sleep(0.2)
            if not ws_url:
                raise RuntimeError("Chrome CDP did not start")

            manifest = [{"url": hpath.resolve().as_uri(), "out": str(r), "w": w, "h": h}
                        for hpath, r, _, w, h in jobs]
            node_script = """
const fs = require('fs');
const jobs = JSON.parse(process.argv[1]);
const ws = new WebSocket(process.argv[2]);
let id = 0;
const pending = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const mid = ++id;
  pending.set(mid, { res, rej });
  ws.send(JSON.stringify({ id: mid, method, params }));
});
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) {
    const p = pending.get(m.id);
    pending.delete(m.id);
    if (m.error) p.rej(new Error(m.error.message));
    else p.res(m.result);
  }
};
ws.onopen = async () => {
  try {
    await send('Page.enable');
    for (const j of jobs) {
      await send('Emulation.setDeviceMetricsOverride', { width: j.w, height: j.h, deviceScaleFactor: 1, mobile: false });
      await send('Page.navigate', { url: j.url });
      await new Promise(r => setTimeout(r, 250));
      const shot = await send('Page.captureScreenshot', { format: 'png' });
      fs.writeFileSync(j.out, Buffer.from(shot.data, 'base64'));
    }
    ws.close();
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
};
"""
            subprocess.run(["node", "-e", node_script, json.dumps(manifest), ws_url], check=True)
        finally:
            chrome_proc.terminate()
            chrome_proc.wait()

        for _, raw_png, final_png, w, h in jobs:
            subprocess.run(
                ["magick", str(raw_png), "-background", "white", "-alpha", "remove", "-alpha", "off",
                 "-colorspace", "sRGB", "-extent", f"{w}x{h}", str(final_png)],
                check=True,
            )
            ident = subprocess.check_output(
                ["magick", "identify", "-format", "%wx%h %[channels] %[colorspace]", str(final_png)],
                text=True,
            ).strip()
            print(f"{final_png.name}: {ident}")
            assert ident.startswith(f"{w}x{h} srgb ") and "srgba" not in ident, f"Unexpected format: {ident}"

    iphone_files = sorted(str(p) for p in args.out_dir.glob("*_iphone69_*.png"))
    ipad_files = sorted(str(p) for p in args.out_dir.glob("*_ipad13_*.png"))
    subprocess.run(["magick", "montage", *iphone_files, "-tile", "4x2", "-geometry", "440x956+16+16",
                    "-background", "#151311", str(args.contact_dir / "contact_iphone.png")], check=True)
    subprocess.run(["magick", "montage", *ipad_files, "-tile", "4x2", "-geometry", "516x688+16+16",
                    "-background", "#151311", str(args.contact_dir / "contact_ipad.png")], check=True)
    print(f"Done! Staged {len(jobs)} posters in {args.out_dir} and contact sheets in {args.contact_dir}.")


if __name__ == "__main__":
    main()
