#!/usr/bin/env python3
"""
Generate Tocamatrol's native Apple Icon Composer bundle at `ios/Tocamatrol/AppIcon.icon`.

Design: 45° Liquid Glass USB-A receiver dongle in anodized steel & cobalt glass housing
a 2x2 Pop-Art macro screen, with incoming wireless signal arcs curving inward from a
remote emitter dot. Adapts cleanly across Default, Dark, Clear, and Tinted appearances.
"""

import json
import math
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ICON_BUNDLE = REPO_ROOT / "ios" / "Tocamatrol" / "AppIcon.icon"


def svg_wrap(body: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">\n'
        f"  {body}\n"
        "</svg>\n"
    )


def rotate_pt(x: float, y: float, cx: float, cy: float, deg: float) -> tuple[float, float]:
    rad = math.radians(deg)
    c, s = math.cos(rad), math.sin(rad)
    dx, dy = x - cx, y - cy
    return (cx + dx * c - dy * s, cy + dx * s + dy * c)


def poly_bezier_subpath(
    corners: list[tuple[float, float]],
    radii: list[float],
    clockwise: bool = True,
) -> str:
    """Closed rounded polygon path with explicit winding (CCW for inner holes)."""
    pts = list(corners)
    rs = list(radii)
    if not clockwise:
        pts = list(reversed(pts))
        rs = list(reversed(rs))

    n = len(pts)
    k = 0.5522847498
    segments = []
    for i in range(n):
        p_prev = pts[(i - 1) % n]
        p_curr = pts[i]
        p_next = pts[(i + 1) % n]
        v1x, v1y = p_prev[0] - p_curr[0], p_prev[1] - p_curr[1]
        v2x, v2y = p_next[0] - p_curr[0], p_next[1] - p_curr[1]
        l1, l2 = math.hypot(v1x, v1y), math.hypot(v2x, v2y)
        r = min(rs[i], l1 * 0.48, l2 * 0.48)
        if r <= 0.01:
            segments.append((p_curr, None, None, p_curr))
        else:
            u1x, u1y = v1x / l1, v1y / l1
            u2x, u2y = v2x / l2, v2y / l2
            a = (p_curr[0] + u1x * r, p_curr[1] + u1y * r)
            b = (p_curr[0] + u2x * r, p_curr[1] + u2y * r)
            c1 = (p_curr[0] + u1x * r * (1 - k), p_curr[1] + u1y * r * (1 - k))
            c2 = (p_curr[0] + u2x * r * (1 - k), p_curr[1] + u2y * r * (1 - k))
            segments.append((a, c1, c2, b))

    parts = [f"M {segments[0][0][0]:.2f} {segments[0][0][1]:.2f}"]
    for i, (a, c1, c2, b) in enumerate(segments):
        if i > 0:
            parts.append(f"L {a[0]:.2f} {a[1]:.2f}")
        if c1 is not None:
            parts.append(f"C {c1[0]:.2f} {c1[1]:.2f} {c2[0]:.2f} {c2[1]:.2f} {b[0]:.2f} {b[1]:.2f}")
    parts.append("Z")
    return " ".join(parts)


def rotated_rect_subpath(
    x: float,
    y: float,
    w: float,
    h: float,
    radii: tuple[float, float, float, float] | float,
    cx: float = 512.0,
    cy: float = 512.0,
    deg: float = 0.0,
    clockwise: bool = True,
) -> str:
    r_list = [float(radii)] * 4 if isinstance(radii, (int, float)) else [float(r) for r in radii]
    raw = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    pts = [rotate_pt(px, py, cx, cy, deg) for px, py in raw]
    return poly_bezier_subpath(pts, r_list, clockwise=clockwise)


def rounded_arc_path(
    cx: float,
    cy: float,
    r_mid: float,
    thickness: float,
    start_deg: float,
    end_deg: float,
) -> str:
    """Closed round-capped thick arc centered at (cx, cy)."""
    r_in = r_mid - thickness / 2
    r_out = r_mid + thickness / 2
    cap_r = thickness / 2

    a0 = math.radians(start_deg)
    a1 = math.radians(end_deg)
    large_arc = 1 if abs(end_deg - start_deg) > 180 else 0

    ox0, oy0 = cx + r_out * math.cos(a0), cy + r_out * math.sin(a0)
    ox1, oy1 = cx + r_out * math.cos(a1), cy + r_out * math.sin(a1)
    ix1, iy1 = cx + r_in * math.cos(a1), cy + r_in * math.sin(a1)
    ix0, iy0 = cx + r_in * math.cos(a0), cy + r_in * math.sin(a0)

    return " ".join(
        [
            f"M {ox0:.2f} {oy0:.2f}",
            f"A {r_out:.2f} {r_out:.2f} 0 {large_arc} 1 {ox1:.2f} {oy1:.2f}",
            f"A {cap_r:.2f} {cap_r:.2f} 0 0 1 {ix1:.2f} {iy1:.2f}",
            f"A {r_in:.2f} {r_in:.2f} 0 {large_arc} 0 {ix0:.2f} {iy0:.2f}",
            f"A {cap_r:.2f} {cap_r:.2f} 0 0 1 {ox0:.2f} {oy0:.2f}",
            "Z",
        ]
    )


def build_app_icon() -> Path:
    cx, cy, ang = 512.0, 512.0, -45.0
    assets: dict[str, str] = {}

    # Backmost hardware layer: Machined USB-A connector (u: -368..-166, v: ±104) with 2 CCW pinholes
    plug_outer = rotated_rect_subpath(512 - 368, 512 - 104, 202, 208, (26, 12, 12, 26), cx, cy, ang, clockwise=True)
    hole_t = rotated_rect_subpath(512 - 322, 512 - 66, 70, 48, 8, cx, cy, ang, clockwise=False)
    hole_b = rotated_rect_subpath(512 - 322, 512 + 18, 70, 48, 8, cx, cy, ang, clockwise=False)
    assets["usb-plug.svg"] = svg_wrap(
        f'<path d="{plug_outer} {hole_t} {hole_b}" fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    # Middle shell: Cobalt Liquid Glass Dongle Housing (u: -184..+186 => w=370, h=308, rx=76)
    assets["barrel.svg"] = svg_wrap(
        f'<path d="{rotated_rect_subpath(512 - 184, 512 - 154, 370, 308, 76, cx, cy, ang)}" fill="#FFFFFF"/>'
    )

    # Dark translucent screen bezel inset on barrel (u: -92..+144 => w=236, v: ±118, rx=44)
    assets["bezel.svg"] = svg_wrap(
        f'<path d="{rotated_rect_subpath(512 - 92, 512 - 118, 236, 236, 44, cx, cy, ang)}" fill="#FFFFFF"/>'
    )

    # Emerald connected status LED clear of USB shoulder overlap (u=-130, v=0)
    lx, ly = rotate_pt(512 - 130, 512, cx, cy, ang)
    assets["status-led.svg"] = svg_wrap(f'<circle cx="{lx:.2f}" cy="{ly:.2f}" r="18" fill="#FFFFFF"/>')

    # Front 2x2 Pop-Art macro tiles inside bezel (centered at u=+26, v=0; k=84, g=16)
    k, g = 84, 16
    u0 = 512 + 26 - (2 * k + g) / 2
    v0 = 512 - (2 * k + g) / 2
    tiles = [
        ("key-tl", u0, v0, "display-p3:0.96000,0.23000,0.18000,1.00000"),
        ("key-tr", u0 + k + g, v0, "display-p3:0.06000,0.84000,0.96000,1.00000"),
        ("key-bl", u0, v0 + k + g, "display-p3:0.15000,0.84000,0.38000,1.00000"),
        ("key-br", u0 + k + g, v0 + k + g, "display-p3:1.00000,0.72000,0.10000,1.00000"),
    ]
    tile_layers = []
    for tid, ux, vy, p3 in tiles:
        fname = f"{tid}.svg"
        assets[fname] = svg_wrap(
            f'<path d="{rotated_rect_subpath(ux, vy, k, k, 22, cx, cy, ang)}" fill="#FFFFFF"/>'
        )
        tile_layers.append(
            {
                "fill": {"automatic-gradient": p3},
                "glass": True,
                "image-name": fname,
                "name": tid.upper(),
            }
        )

    # Top-right Emitter dot (u=+384, v=0) + incoming waves radiating SW into dongle nose
    ex, ey = rotate_pt(512 + 384, 512, cx, cy, ang)
    assets["emitter-dot.svg"] = svg_wrap(f'<circle cx="{ex:.2f}" cy="{ey:.2f}" r="26" fill="#FFFFFF"/>')
    assets["rx-wave-1.svg"] = svg_wrap(
        f'<path d="{rounded_arc_path(ex, ey, 84, 24, 96, 174)}" fill="#FFFFFF"/>'
    )
    assets["rx-wave-2.svg"] = svg_wrap(
        f'<path d="{rounded_arc_path(ex, ey, 148, 24, 96, 174)}" fill="#FFFFFF"/>'
    )

    spec = {
        "fill-specializations": [
            {
                "value": {
                    "linear-gradient": [
                        "display-p3:0.98500,0.98200,0.96800,1.00000",
                        "display-p3:0.93000,0.92400,0.90800,1.00000",
                    ]
                }
            },
            {
                "appearance": "dark",
                "value": {
                    "linear-gradient": [
                        "display-p3:0.10500,0.14500,0.31000,1.00000",
                        "display-p3:0.04200,0.06000,0.14500,1.00000",
                    ]
                },
            },
        ],
        "groups": [
            {
                "layers": [
                    {
                        "fill": {"automatic-gradient": "display-p3:0.96000,0.23000,0.18000,1.00000"},
                        "glass": True,
                        "image-name": "emitter-dot.svg",
                        "name": "Remote Transmitter Dot",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:1.00000,0.52000,0.12000,1.00000"},
                        "glass": True,
                        "image-name": "rx-wave-1.svg",
                        "name": "Incoming Wave 1",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:0.96000,0.23000,0.18000,1.00000"},
                        "glass": True,
                        "image-name": "rx-wave-2.svg",
                        "name": "Incoming Wave 2",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:0.16000,0.88000,0.42000,1.00000"},
                        "glass": True,
                        "image-name": "status-led.svg",
                        "name": "Status LED",
                    },
                ]
                + tile_layers,
                "shadow": {"kind": "neutral", "opacity": 0.42},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.28},
            },
            {
                "layers": [
                    {
                        "fill": {"solid": "display-p3:0.06500,0.08500,0.16500,1.00000"},
                        "glass": True,
                        "image-name": "bezel.svg",
                        "name": "Macro Screen Bezel",
                        "opacity": 0.92,
                    }
                ],
                "shadow": {"kind": "neutral", "opacity": 0.25},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.30},
            },
            {
                "layers": [
                    {
                        "fill": {"automatic-gradient": "display-p3:0.10000,0.52000,0.99000,1.00000"},
                        "glass": True,
                        "image-name": "barrel.svg",
                        "name": "USB Receiver Body",
                    }
                ],
                "shadow": {"kind": "neutral", "opacity": 0.48},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.45},
            },
            {
                "layers": [
                    {
                        "fill-specializations": [
                            {
                                "value": {
                                    "automatic-gradient": "display-p3:0.42000,0.48000,0.59000,1.00000"
                                }
                            },
                            {
                                "appearance": "dark",
                                "value": {
                                    "automatic-gradient": "display-p3:0.74000,0.80000,0.90000,1.00000"
                                },
                            },
                        ],
                        "glass": True,
                        "image-name": "usb-plug.svg",
                        "name": "USB-A Connector",
                    }
                ],
                "shadow": {"kind": "neutral", "opacity": 0.54},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.22},
            },
        ],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }

    assets_dir = ICON_BUNDLE / "Assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    for existing in assets_dir.glob("*.svg"):
        existing.unlink()
    for filename, svg_content in assets.items():
        (assets_dir / filename).write_text(svg_content, encoding="utf-8")
    (ICON_BUNDLE / "icon.json").write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
    return ICON_BUNDLE


if __name__ == "__main__":
    print(f"Generated {build_app_icon()}")
