#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["evdev>=1.7"]
# ///
"""Print what the Tocamatrol dongle sends to a Linux PC, as input events.

Plug the dongle into this computer, run this, then drive the dongle from another
machine with send_test.py. Needs read access to /dev/input (root or the `input` group).

    sudo uv run tools/watch_hid.py
"""

from __future__ import annotations

import selectors
import sys
import time

import evdev
from evdev import ecodes

PRODUCT_NAME = "Tocamatrol"


def find_devices() -> list[evdev.InputDevice]:
    found = []
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        if PRODUCT_NAME in dev.name:
            found.append(dev)
    return found


def main() -> None:
    devices = find_devices()
    if not devices:
        sys.exit(f"no input device named like '{PRODUCT_NAME}'; is the dongle plugged in, and are you root?")
    sel = selectors.DefaultSelector()
    for dev in devices:
        print(f"watching {dev.path}: {dev.name}")
        sel.register(dev, selectors.EVENT_READ)

    totals = {"x": 0, "y": 0, "wheel": 0, "hwheel": 0, "reports": 0}
    last_print = time.monotonic()
    while True:
        for key, _ in sel.select(timeout=1.0):
            for ev in key.fileobj.read():
                if ev.type == ecodes.EV_REL:
                    if ev.code == ecodes.REL_X:
                        totals["x"] += ev.value
                    elif ev.code == ecodes.REL_Y:
                        totals["y"] += ev.value
                    elif ev.code == ecodes.REL_WHEEL:
                        totals["wheel"] += ev.value
                        print(f"wheel {ev.value:+d} (total {totals['wheel']:+d})")
                    elif ev.code == ecodes.REL_HWHEEL:
                        totals["hwheel"] += ev.value
                        print(f"hwheel {ev.value:+d} (total {totals['hwheel']:+d})")
                elif ev.type == ecodes.EV_KEY:
                    name = ecodes.BTN.get(ev.code) or ecodes.KEY.get(ev.code) or ev.code
                    print(f"{name} {'down' if ev.value else 'up'}")
                elif ev.type == ecodes.EV_SYN:
                    totals["reports"] += 1
        now = time.monotonic()
        if now - last_print >= 1.0 and totals["reports"]:
            print(f"pointer total x {totals['x']:+d} y {totals['y']:+d}  reports {totals['reports']}")
            last_print = now


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
