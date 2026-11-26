#!/usr/bin/env python3
"""
Generate Tocamatrol's native Apple Icon Composer bundle at `ios/Tocamatrol/AppIcon.icon`.

Design: Ink & Pop meets Liquid Glass — a 45° USB-A receiver dongle framed in bold
India-ink keylines (Electric Cobalt in Dark Mode) over Bright Newsprint / Dark Electric
Comic Ben-Day halftone paper, housing a dark ink key-well with 2x2 Pop-Art macro tiles
and bold comic wireless reception arcs curving inward from a remote emitter dot.
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


def rotated_ring_subpath(
    x: float,
    y: float,
    w: float,
    h: float,
    radii: tuple[float, float, float, float] | float,
    stroke_out: float,
    stroke_in: float = 3.0,
    cx: float = 512.0,
    cy: float = 512.0,
    deg: float = 0.0,
) -> str:
    """Hollow evenodd comic ink outline collar hugging a rotated rounded rect."""
    r_list = [float(radii)] * 4 if isinstance(radii, (int, float)) else [float(r) for r in radii]
    outer_r = tuple(r + stroke_out for r in r_list)
    inner_r = tuple(max(0.0, r - stroke_in) for r in r_list)
    outer = rotated_rect_subpath(
        x - stroke_out,
        y - stroke_out,
        w + 2 * stroke_out,
        h + 2 * stroke_out,
        outer_r,
        cx,
        cy,
        deg,
        clockwise=True,
    )
    inner = rotated_rect_subpath(
        x + stroke_in,
        y + stroke_in,
        w - 2 * stroke_in,
        h - 2 * stroke_in,
        inner_r,
        cx,
        cy,
        deg,
        clockwise=False,
    )
    return f"{outer} {inner}"


def circle_ring_subpath(cx: float, cy: float, r_outer: float, r_inner: float) -> str:
    """Hollow evenodd circular ring."""
    out = (
        f"M {cx + r_outer:.2f} {cy:.2f} "
        f"A {r_outer:.2f} {r_outer:.2f} 0 1 1 {cx - r_outer:.2f} {cy:.2f} "
        f"A {r_outer:.2f} {r_outer:.2f} 0 1 1 {cx + r_outer:.2f} {cy:.2f} Z"
    )
    inn = (
        f"M {cx + r_inner:.2f} {cy:.2f} "
        f"A {r_inner:.2f} {r_inner:.2f} 0 1 0 {cx - r_inner:.2f} {cy:.2f} "
        f"A {r_inner:.2f} {r_inner:.2f} 0 1 0 {cx + r_inner:.2f} {cy:.2f} Z"
    )
    return f"{out} {inn}"


def rounded_arc_path(
    cx: float,
    cy: float,
    r_mid: float,
    thickness: float,
    start_deg: float,
    end_deg: float,
    clockwise: bool = True,
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

    if clockwise:
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
    return " ".join(
        [
            f"M {ox0:.2f} {oy0:.2f}",
            f"A {cap_r:.2f} {cap_r:.2f} 0 0 0 {ix0:.2f} {iy0:.2f}",
            f"A {r_in:.2f} {r_in:.2f} 0 {large_arc} 1 {ix1:.2f} {iy1:.2f}",
            f"A {cap_r:.2f} {cap_r:.2f} 0 0 0 {ox1:.2f} {oy1:.2f}",
            f"A {r_out:.2f} {r_out:.2f} 0 {large_arc} 0 {ox0:.2f} {oy0:.2f}",
            "Z",
        ]
    )


def rounded_arc_collar_path(
    cx: float,
    cy: float,
    r_mid: float,
    inner_thickness: float,
    pad: float,
    start_deg: float,
    end_deg: float,
) -> str:
    """Hollow evenodd comic ink outline collar around a round-capped thick arc."""
    outer = rounded_arc_path(cx, cy, r_mid, inner_thickness + 2 * pad, start_deg, end_deg, clockwise=True)
    inner = rounded_arc_path(cx, cy, r_mid, max(4.0, inner_thickness - 4.0), start_deg, end_deg, clockwise=False)
    return f"{outer} {inner}"


def halftone_dots_path() -> str:
    """Staggered comic Ben-Day halftone pattern matching Theme.swift HalftoneBackground."""
    spacing = 64.0
    r = 9.0
    parts: list[str] = []
    cols = int(1024 / spacing) + 2
    rows = int(1024 / spacing) + 2
    for row in range(rows):
        x_off = 0.0 if row % 2 == 0 else spacing / 2.0
        y = row * spacing + 16.0
        for col in range(cols):
            x = col * spacing + x_off + 8.0
            parts.append(
                f"M {x + r:.1f} {y:.1f} "
                f"A {r:.1f} {r:.1f} 0 1 1 {x - r:.1f} {y:.1f} "
                f"A {r:.1f} {r:.1f} 0 1 1 {x + r:.1f} {y:.1f} Z"
            )
    return " ".join(parts)


def build_app_icon() -> Path:
    cx, cy, ang = 512.0, 512.0, -45.0
    assets: dict[str, str] = {}

    # 1. Staggered comic Ben-Day halftone texture across the newsprint / electric-comic field.
    assets["halftone.svg"] = svg_wrap(f'<path d="{halftone_dots_path()}" fill="#FFFFFF"/>')

    # 2. Machined USB-A connector (u: -374..-180.65, v: +-102) contoured to butt flush
    #    against the receiver barrel's curved left shoulder so zero plug edge shows inside glass.
    plug_corners = [
        rotate_pt(512 - 374, 512 - 102, cx, cy, ang),
        rotate_pt(512 - 180.65, 512 - 102, cx, cy, ang),
        rotate_pt(512 - 184, 512 - 80, cx, cy, ang),
        rotate_pt(512 - 184, 512 + 80, cx, cy, ang),
        rotate_pt(512 - 180.65, 512 + 102, cx, cy, ang),
        rotate_pt(512 - 374, 512 + 102, cx, cy, ang),
    ]
    plug_radii = [26.0, 2.0, 2.0, 2.0, 2.0, 26.0]
    plug_outer = poly_bezier_subpath(plug_corners, plug_radii, clockwise=True)
    h_t_box = (512 - 326, 512 - 64, 68, 46, 8)
    h_b_box = (512 - 326, 512 + 18, 68, 46, 8)
    hole_t = rotated_rect_subpath(*h_t_box, cx, cy, ang, clockwise=False)
    hole_b = rotated_rect_subpath(*h_b_box, cx, cy, ang, clockwise=False)
    assets["usb-plug.svg"] = svg_wrap(
        f'<path d="{plug_outer} {hole_t} {hole_b}" fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    plug_ink_corners = [
        rotate_pt(512 - 385, 512 - 113, cx, cy, ang),
        rotate_pt(512 - 178, 512 - 113, cx, cy, ang),
        rotate_pt(512 - 178, 512 + 113, cx, cy, ang),
        rotate_pt(512 - 385, 512 + 113, cx, cy, ang),
    ]
    plug_ink_outer = poly_bezier_subpath(plug_ink_corners, [37.0, 2.0, 2.0, 37.0], clockwise=True)
    plug_ink_inner = poly_bezier_subpath(
        [
            rotate_pt(512 - 371, 512 - 99, cx, cy, ang),
            rotate_pt(512 - 186, 512 - 99, cx, cy, ang),
            rotate_pt(512 - 186, 512 + 99, cx, cy, ang),
            rotate_pt(512 - 371, 512 + 99, cx, cy, ang),
        ],
        [23.0, 2.0, 2.0, 23.0],
        clockwise=False,
    )
    hole_t_ink = rotated_ring_subpath(*h_t_box, 10, 2, cx, cy, ang)
    hole_b_ink = rotated_ring_subpath(*h_b_box, 10, 2, cx, cy, ang)
    assets["usb-plug-ink.svg"] = svg_wrap(
        f'<path d="{plug_ink_outer} {plug_ink_inner} {hole_t_ink} {hole_b_ink}" fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    # 3. Hero Cobalt Receiver Housing (u: -184..+186, v: +-154) + bold India-ink comic collar
    bar_x, bar_y, bar_w, bar_h, bar_r = 512 - 184, 512 - 154, 370, 308, 74
    assets["barrel.svg"] = svg_wrap(
        f'<path d="{rotated_rect_subpath(bar_x, bar_y, bar_w, bar_h, bar_r, cx, cy, ang)}" fill="#FFFFFF"/>'
    )
    assets["barrel-ink.svg"] = svg_wrap(
        f'<path d="{rotated_ring_subpath(bar_x, bar_y, bar_w, bar_h, bar_r, 12, 4, cx, cy, ang)}" '
        'fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    # 4. Hard-offset comic drop shadow tucked strictly outside the bottom-right silhouette
    sdx, sdy = 512 + 18, 512 + 22
    bar_shadow_outer = rotated_rect_subpath(bar_x, bar_y, bar_w, bar_h, bar_r, sdx, sdy, ang, clockwise=True)
    bar_shadow_cut = rotated_rect_subpath(bar_x + 4, bar_y + 4, bar_w - 8, bar_h - 8, bar_r - 4, cx, cy, ang, clockwise=False)
    plug_shadow_outer = poly_bezier_subpath(
        [
            rotate_pt(512 - 374, 512 - 102, sdx, sdy, ang),
            rotate_pt(512 - 184, 512 - 102, sdx, sdy, ang),
            rotate_pt(512 - 184, 512 + 102, sdx, sdy, ang),
            rotate_pt(512 - 374, 512 + 102, sdx, sdy, ang),
        ],
        [26.0, 2.0, 2.0, 26.0],
        clockwise=True,
    )
    plug_shadow_cut = poly_bezier_subpath(
        [
            rotate_pt(512 - 370, 512 - 98, cx, cy, ang),
            rotate_pt(512 - 186, 512 - 98, cx, cy, ang),
            rotate_pt(512 - 186, 512 + 98, cx, cy, ang),
            rotate_pt(512 - 370, 512 + 98, cx, cy, ang),
        ],
        [22.0, 2.0, 2.0, 22.0],
        clockwise=False,
    )
    assets["comic-drop.svg"] = svg_wrap(
        f'<path d="{bar_shadow_outer} {bar_shadow_cut} {plug_shadow_outer} {plug_shadow_cut}" fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    # 5. Deep India-Ink key-well bezel around the 2x2 Pop-Art macro keycaps (u: -90..+146, v: +-118)
    bez_x, bez_y, bez_w, bez_h, bez_r = 512 - 90, 512 - 118, 236, 236, 42
    assets["bezel.svg"] = svg_wrap(
        f'<path d="{rotated_rect_subpath(bez_x, bez_y, bez_w, bez_h, bez_r, cx, cy, ang)}" fill="#FFFFFF"/>'
    )

    # 6. Power Emerald LED + hollow ink collar (u=-132, v=0)
    lx, ly = rotate_pt(512 - 132, 512, cx, cy, ang)
    assets["status-led.svg"] = svg_wrap(f'<circle cx="{lx:.2f}" cy="{ly:.2f}" r="18" fill="#FFFFFF"/>')
    assets["status-led-ink.svg"] = svg_wrap(
        f'<path d="{circle_ring_subpath(lx, ly, 25, 14)}" fill="#FFFFFF" fill-rule="evenodd"/>'
    )

    # 7. Four Ink & Pop macro keycaps matching Theme.swift KeyStyle (cyan, yellow, vermilion, green)
    k, g = 82, 18
    u0 = 512 + 28 - (2 * k + g) / 2
    v0 = 512 - (2 * k + g) / 2
    tiles = [
        ("key-tl", u0, v0, "display-p3:0.87500,0.16100,0.12500,1.00000"),          # Hero Vermilion (#DF2920)
        ("key-tr", u0 + k + g, v0, "display-p3:0.06000,0.77300,0.87100,1.00000"),  # Electric Cyan (#0FC5DE)
        ("key-bl", u0, v0 + k + g, "display-p3:0.13300,0.76900,0.27800,1.00000"),  # Power Emerald (#22C447)
        ("key-br", u0 + k + g, v0 + k + g, "display-p3:1.00000,0.82400,0.12200,1.00000"),  # Sunburst Yellow (#FFD21F)
    ]
    tile_layers = []
    for tid, ux, vy, p3 in tiles:
        fname = f"{tid}.svg"
        assets[fname] = svg_wrap(
            f'<path d="{rotated_rect_subpath(ux, vy, k, k, 20, cx, cy, ang)}" fill="#FFFFFF"/>'
        )
        tile_layers.append(
            {
                "fill": {"automatic-gradient": p3},
                "glass": True,
                "image-name": fname,
                "name": tid.upper(),
            }
        )

    # 8. Top-right wireless emitter dot + incoming SW reception arcs + hollow India-ink collars
    ex, ey = rotate_pt(512 + 382, 512, cx, cy, ang)
    assets["emitter-dot.svg"] = svg_wrap(f'<circle cx="{ex:.2f}" cy="{ey:.2f}" r="25" fill="#FFFFFF"/>')
    assets["rx-wave-1.svg"] = svg_wrap(
        f'<path d="{rounded_arc_path(ex, ey, 84, 24, 96, 174)}" fill="#FFFFFF"/>'
    )
    assets["rx-wave-2.svg"] = svg_wrap(
        f'<path d="{rounded_arc_path(ex, ey, 148, 24, 96, 174)}" fill="#FFFFFF"/>'
    )
    waves_ink = " ".join(
        [
            circle_ring_subpath(ex, ey, 33, 21),
            rounded_arc_collar_path(ex, ey, 84, 24, 8, 96, 174),
            rounded_arc_collar_path(ex, ey, 148, 24, 8, 96, 174),
        ]
    )
    assets["waves-ink.svg"] = svg_wrap(f'<path d="{waves_ink}" fill="#FFFFFF" fill-rule="evenodd"/>')

    # Spec mirrors Theme.swift (Bright Newsprint / Dark Electric Comic, unified KeyStyle ink keylines)
    ink_light = "display-p3:0.08200,0.07500,0.06700,1.00000"    # #151311 India Ink
    ink_dark_edge = "display-p3:0.03000,0.04200,0.10000,1.00000" # #090D1C KeyStyle Dark Ink

    spec = {
        "fill-specializations": [
            {
                "value": {
                    "linear-gradient": [
                        "display-p3:1.00000,0.96800,0.87500,1.00000",  # Bright Newsprint (#FFF6DF)
                        "display-p3:0.99200,0.90200,0.61000,1.00000",  # Sunlit Comic Cream
                    ]
                }
            },
            {
                "appearance": "dark",
                "value": {
                    "linear-gradient": [
                        "display-p3:0.10500,0.14500,0.34500,1.00000",  # Dark Electric Comic (#10152B)
                        "display-p3:0.04200,0.05600,0.13500,1.00000",  # Midnight Panel Well (#0A0E1F)
                    ]
                },
            },
        ],
        "groups": [
            {
                "layers": [
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": ink_dark_edge}},
                        ],
                        "glass": False,
                        "image-name": "waves-ink.svg",
                        "name": "Signal Comic Ink Outlines",
                        "opacity": 0.94,
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:0.87500,0.16100,0.12500,1.00000"},
                        "glass": True,
                        "image-name": "emitter-dot.svg",
                        "name": "Remote Emitter Dot",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:1.00000,0.45100,0.08200,1.00000"},
                        "glass": True,
                        "image-name": "rx-wave-1.svg",
                        "name": "Incoming Wave Inner",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:1.00000,0.82400,0.12200,1.00000"},
                        "glass": True,
                        "image-name": "rx-wave-2.svg",
                        "name": "Incoming Wave Outer",
                    },
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": ink_dark_edge}},
                        ],
                        "glass": False,
                        "image-name": "status-led-ink.svg",
                        "name": "Status LED Ink Ring",
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:0.16000,0.90000,0.44000,1.00000"},
                        "glass": True,
                        "image-name": "status-led.svg",
                        "name": "Status LED",
                    },
                ]
                + tile_layers
                + [
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": "display-p3:0.03900,0.05500,0.12500,1.00000"}},
                        ],
                        "glass": True,
                        "image-name": "bezel.svg",
                        "name": "Comic Key-Well Bezel",
                        "opacity": 0.96,
                    }
                ],
                "shadow": {"kind": "neutral", "opacity": 0.42},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.24},
            },
            {
                "layers": [
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": ink_dark_edge}},
                        ],
                        "glass": False,
                        "image-name": "barrel-ink.svg",
                        "name": "Receiver Body Ink Outline",
                        "opacity": 0.95,
                    },
                    {
                        "fill": {"automatic-gradient": "display-p3:0.10200,0.35700,0.87800,1.00000"},
                        "glass": True,
                        "image-name": "barrel.svg",
                        "name": "USB Receiver Body (Hero Cobalt)",
                    },
                ],
                "shadow": {"kind": "neutral", "opacity": 0.45},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.28},
            },
            {
                "layers": [
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": ink_dark_edge}},
                        ],
                        "glass": False,
                        "image-name": "usb-plug-ink.svg",
                        "name": "USB-A Connector Ink Outline",
                        "opacity": 0.95,
                    },
                    {
                        "fill-specializations": [
                            {"value": {"automatic-gradient": "display-p3:0.78500,0.83000,0.90000,1.00000"}},
                            {"appearance": "dark", "value": {"automatic-gradient": "display-p3:0.83000,0.87500,0.95500,1.00000"}},
                        ],
                        "glass": True,
                        "image-name": "usb-plug.svg",
                        "name": "USB-A Connector",
                    },
                ],
                "shadow": {"kind": "neutral", "opacity": 0.48},
                "specular": True,
                "translucency": {"enabled": True, "value": 0.20},
            },
            {
                "layers": [
                    {
                        "fill-specializations": [
                            {"value": {"solid": ink_light}},
                            {"appearance": "dark", "value": {"solid": ink_dark_edge}},
                        ],
                        "glass": False,
                        "image-name": "comic-drop.svg",
                        "name": "Hard Offset Comic Block",
                        "opacity": 0.90,
                    },
                    {
                        "fill-specializations": [
                            {"value": {"solid": "display-p3:0.08200,0.07500,0.06700,0.08500"}},
                            {"appearance": "dark", "value": {"solid": "display-p3:0.33700,0.65900,1.00000,0.14000"}},
                        ],
                        "glass": False,
                        "image-name": "halftone.svg",
                        "name": "Ben-Day Comic Halftone",
                    },
                ],
                "specular": False,
                "translucency": {"enabled": False, "value": 0.0},
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
