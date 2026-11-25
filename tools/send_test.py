#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["bleak>=0.22"]
# ///
"""Drive the Tocamatrol dongle over BLE without the phone.

Connects to the dongle, reads its Info characteristic, then sends scripted pointer
packets (moves, clicks, a drag, vertical and horizontal scrolls, a large move that must
be split) and keyboard packets at the 15 ms send tick. Packet layout: ../protocol/PROTOCOL.md.

    uv run tools/send_test.py                 # every scenario but stress and keys
    uv run tools/send_test.py keys            # types "Tocamatrol" and presses Ctrl+C
    uv run tools/send_test.py scroll click    # chosen scenarios
    uv run tools/send_test.py --dry-run       # print packets, no Bluetooth
    uv run tools/send_test.py --selftest      # check the encoder against PROTOCOL.md

Pairing: the dongle asks to pair as soon as you connect. Plug it in (or press its
button) less than 60 s before the first run so its pairing window is open. On macOS,
accept the pairing prompt if one appears.
"""

from __future__ import annotations

import argparse
import asyncio
import math
import struct
import sys
import time
from collections.abc import Iterator

SERVICE_UUID = "cc8e0001-115b-4a7a-8d7c-16299db8fcaf"
INPUT_UUID = "cc8e0002-115b-4a7a-8d7c-16299db8fcaf"
INFO_UUID = "cc8e0003-115b-4a7a-8d7c-16299db8fcaf"
DEVICE_NAME = "Tocamatrol"

SEND_TICK_S = 0.015
LEFT, RIGHT, MIDDLE = 0x01, 0x02, 0x04
HEADER_POINTER_V1 = 0x01  # version 1, type 0
HEADER_KEYBOARD_V1 = 0x11  # version 1, type 1
LEFT_CTRL, LEFT_SHIFT = 0x01, 0x02


def encode_pointer(seq: int, buttons: int, dx: int, dy: int, vscroll: int, hscroll: int = 0) -> bytes:
    """Pointer packet, 11 bytes little-endian (PROTOCOL.md "Pointer packet")."""
    return struct.pack("<BBBhhhh", HEADER_POINTER_V1, seq & 0xFF, buttons, dx, dy, vscroll, hscroll)


def encode_pointer_legacy(seq: int, buttons: int, dx: int, dy: int, vscroll: int) -> bytes:
    """Legacy 9-byte pointer packet without hscroll (PROTOCOL.md "Pointer packet")."""
    return struct.pack("<BBBhhh", HEADER_POINTER_V1, seq & 0xFF, buttons, dx, dy, vscroll)


def encode_keyboard(seq: int, modifiers: int, keys: list[int]) -> bytes:
    """Keyboard packet, 9 bytes (PROTOCOL.md "Keyboard packet")."""
    return bytes([HEADER_KEYBOARD_V1, seq & 0xFF, modifiers, *keys[:6], *[0] * (6 - len(keys[:6]))])


# A step is one send tick: a pointer packet's (buttons, dx, dy, vscroll[, hscroll]), or a
# keyboard packet's ("keys", modifiers, [usages held]).
Step = tuple


class Encoder:
    """Encodes steps; each packet type counts its own seq."""

    def __init__(self) -> None:
        self.seq = {"pointer": 0, "keys": 0}

    def encode(self, step: Step) -> bytes:
        if step[0] == "keys":
            packet = encode_keyboard(self.seq["keys"], step[1], step[2])
            self.seq["keys"] += 1
        else:
            packet = encode_pointer(self.seq["pointer"], *step)
            self.seq["pointer"] += 1
        return packet


def scenario_move() -> Iterator[Step]:
    """A circle of radius ~200 px over 2 s, then a square."""
    ticks = 133
    for i in range(ticks):
        a0, a1 = 2 * math.pi * i / ticks, 2 * math.pi * (i + 1) / ticks
        yield 0, round(200 * (math.cos(a1) - math.cos(a0))), round(200 * (math.sin(a1) - math.sin(a0))), 0, 0
    for dx, dy in [(10, 0), (0, 10), (-10, 0), (0, -10)]:
        for _ in range(20):
            yield 0, dx, dy, 0, 0


def scenario_click() -> Iterator[Step]:
    """Left click, pause, right click (opens a context menu)."""
    yield LEFT, 0, 0, 0, 0
    yield 0, 0, 0, 0, 0
    yield from [(0, 0, 0, 0, 0)] * 30
    yield RIGHT, 0, 0, 0, 0
    yield 0, 0, 0, 0, 0


def scenario_drag() -> Iterator[Step]:
    """Press, move 300 px right while held, release."""
    yield LEFT, 0, 0, 0, 0
    for _ in range(30):
        yield LEFT, 10, 0, 0, 0
    yield 0, 0, 0, 0, 0


def scenario_scroll() -> Iterator[Step]:
    """Vertical and horizontal scroll ticks."""
    yield from [(0, 0, 0, -1, 0)] * 10
    yield from [(0, 0, 0, 0, 0)] * 30
    yield from [(0, 0, 0, 1, 0)] * 10
    yield from [(0, 0, 0, 0, 0)] * 30
    yield from [(0, 0, 0, 0, 1)] * 5
    yield from [(0, 0, 0, 0, -1)] * 5
    yield 0, 0, 0, -30, 0


def scenario_split() -> Iterator[Step]:
    """One packet far beyond a single report (+1000, +500), then back."""
    yield 0, 1000, 500, 0, 0
    yield from [(0, 0, 0, 0, 0)] * 30
    yield 0, -1000, -500, 0, 0


def scenario_stress() -> Iterator[Step]:
    """5 s of continuous small moves at the full send tick rate, for packets/s and seq gaps."""
    for i in range(int(5 / SEND_TICK_S)):
        yield 0, 3 if (i // 50) % 2 == 0 else -3, 0, 0, 0


def scenario_keys() -> Iterator[Step]:
    """Types "Tocamatrol", pauses, then sends Ctrl+C."""
    usages = {
        "t": 0x17,
        "o": 0x12,
        "c": 0x06,
        "a": 0x04,
        "m": 0x10,
        "r": 0x15,
        "l": 0x0F,
    }
    yield "keys", LEFT_SHIFT, [usages["t"]]
    yield "keys", 0, []
    for ch in "ocamatrol":
        yield "keys", 0, [usages[ch]]
        yield "keys", 0, []
    yield from [(0, 0, 0, 0, 0)] * 10
    yield "keys", LEFT_CTRL, [usages["c"]]
    yield "keys", 0, []


SCENARIOS = {
    "move": scenario_move,
    "click": scenario_click,
    "drag": scenario_drag,
    "scroll": scenario_scroll,
    "split": scenario_split,
    "stress": scenario_stress,
    "keys": scenario_keys,
}
NOT_BY_DEFAULT = {"stress", "keys"}


def selftest() -> None:
    # PROTOCOL.md 11-byte example: left held, right 3, up 2, vscroll -1, hscroll +2, seq 7.
    expected = bytes.fromhex("01 07 01 03 00 FE FF FF FF 02 00")
    got = encode_pointer(7, LEFT, 3, -2, -1, 2)
    assert got == expected, f"encoder mismatch: {got.hex(' ')} != {expected.hex(' ')}"
    assert encode_pointer_legacy(7, LEFT, 3, -2, -1) == bytes.fromhex("01 07 01 03 00 FE FF FF FF")
    assert len(encode_pointer(255, 0, -32768, 32767, 0, -32768)) == 11
    assert encode_pointer(256, 0, 0, 0, 0, 0)[1] == 0, "seq must wrap at 256"
    # PROTOCOL.md example: Ctrl held with C (0x06), seq 4.
    expected = bytes.fromhex("11 04 01 06 00 00 00 00 00")
    got = encode_keyboard(4, LEFT_CTRL, [0x06])
    assert got == expected, f"encoder mismatch: {got.hex(' ')} != {expected.hex(' ')}"
    print("selftest: encoder matches PROTOCOL.md")


async def run(names: list[str], dry_run: bool, address: str | None) -> None:
    packets = [step for name in names for step in SCENARIOS[name]()]
    if dry_run:
        encoder = Encoder()
        for n, step in enumerate(packets):
            print(f"{n:4d}  {encoder.encode(step).hex(' ')}")
        return

    from bleak import BleakClient, BleakScanner

    if address is None:
        print(f"scanning for {DEVICE_NAME} ...")
        device = await BleakScanner.find_device_by_filter(
            lambda d, adv: SERVICE_UUID in [u.lower() for u in adv.service_uuids] or d.name == DEVICE_NAME,
            timeout=15,
        )
        if device is None:
            sys.exit("no Tocamatrol dongle found")
        address = device.address
    print(f"connecting to {address} ...")
    async with BleakClient(address) as client:
        try:
            info = await client.read_gatt_char(INFO_UUID)
        except Exception as e:  # noqa: BLE001 - bleak raises backend-specific errors
            sys.exit(f"Info read failed ({e}); the dongle may be outside its pairing window. "
                     "Press its button and retry; on macOS also remove Tocamatrol in Bluetooth settings.")
        if len(info) >= 4:
            print(f"dongle: protocol {info[0]}, firmware {info[1]}.{info[2]}, pairing window {'open' if info[3] & 1 else 'closed'}")
        for name in names:
            print(f"scenario {name}")
        start = time.perf_counter()
        next_tick = start
        encoder = Encoder()
        for step in packets:
            await client.write_gatt_char(INPUT_UUID, encoder.encode(step), response=False)
            next_tick += SEND_TICK_S
            await asyncio.sleep(max(0.0, next_tick - time.perf_counter()))
        elapsed = time.perf_counter() - start
        await client.write_gatt_char(INPUT_UUID, encoder.encode((0, 0, 0, 0, 0)), response=False)
        await client.write_gatt_char(INPUT_UUID, encoder.encode(("keys", 0, [])), response=False)
        print(f"sent {len(packets) + 2} packets in {elapsed:.2f} s ({len(packets) / elapsed:.0f}/s)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenarios", nargs="*", help=f"any of {', '.join(SCENARIOS)}; default: all except {' and '.join(sorted(NOT_BY_DEFAULT))}")
    parser.add_argument("--dry-run", action="store_true", help="print packets instead of sending")
    parser.add_argument("--selftest", action="store_true", help="check the encoder and exit")
    parser.add_argument("--address", help="dongle address or macOS UUID; skips scanning")
    args = parser.parse_args()
    if args.selftest:
        selftest()
        return
    unknown = [n for n in args.scenarios if n not in SCENARIOS]
    if unknown:
        parser.error(f"unknown scenario {', '.join(unknown)}; choose from {', '.join(SCENARIOS)}")
    names = args.scenarios or [n for n in SCENARIOS if n not in NOT_BY_DEFAULT]
    asyncio.run(run(names, args.dry_run, args.address))


if __name__ == "__main__":
    main()
