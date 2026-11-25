# Tocamatrol BLE protocol

This file is the single source of truth for the link between the **phone** and the
**dongle**. Change this file first, then the firmware decoder (`dongle/lib/toca_core/src/toca/packet.h`),
the Swift encoder (`ios/TocaCore/Sources/TocaCore/Packet.swift`), and the test sender
(`tools/send_test.py`).

Protocol version: **1**.

## Roles

| Role | Device | Job |
| --- | --- | --- |
| Peripheral (GATT server) | Dongle | Advertises, holds the bonds, turns packets into USB HID reports. |
| Central (GATT client) | Phone, tablet, or other BLE sender | Scans, connects, writes packets. |

A **sender** is any central that writes packets (for example an iPhone and an iPad connected
at the same time).

## Advertising

- Local name (in the scan response): the dongle's [name](#name-characteristic). Until a
  phone names it, that is `Tocamatrol XXXX`, where `XXXX` is the last two bytes of the
  dongle's Bluetooth address in upper-case hex. A dongle with a screen shows its name, so a
  person can match the name in the app to the dongle in front of them. Phones find dongles
  by the service UUID, never by the name.
- Advertised service: the Tocamatrol service UUID below.
- Manufacturer data: company ID `0xFFFF` (reserved for testing, little-endian `FF FF`),
  then one `flags` byte. Bit 0: the pairing window is open. Bits 1–7 are 0. The phone
  uses it to show which dongle is ready to pair; it changes nothing about bonding.

  Example, pairing window open: `FF FF 01`.
- The dongle advertises whenever it has a free connection slot, and updates the
  advertisement when its pairing window opens or closes. It supports up to 3 senders
  connected at once (NimBLE's precompiled limit). See [Several senders](#several-senders).

## GATT

| Item | UUID | Properties | Security |
| --- | --- | --- | --- |
| Tocamatrol service | `cc8e0001-115b-4a7a-8d7c-16299db8fcaf` | primary | |
| Input characteristic | `cc8e0002-115b-4a7a-8d7c-16299db8fcaf` | write without response | encrypted, bonded |
| Info characteristic | `cc8e0003-115b-4a7a-8d7c-16299db8fcaf` | read | encrypted |
| Name characteristic | `cc8e0004-115b-4a7a-8d7c-16299db8fcaf` | read, write | encrypted, bonded |

A write without response gets no error back, so a phone is never told it must pair. The
dongle therefore sends a security request as soon as a phone connects. See
[Bonding](#bonding).

## Several senders

Up to 3 senders may be connected and sending at once, for example an iPhone and an iPad.
Packets need no sender field: the dongle knows each sender by its connection.

- **State is per sender.** Each sender's pointer packets carry *its* buttons, and its
  keyboard packets carry *its* keys and modifiers. The dongle keeps each sender's state
  apart and reports the union to the PC: a button or modifier is held while any sender
  holds it; the held keys are every sender's keys, each once, at most 6 (later senders'
  keys past 6 are not sent).
- **Movement adds up.** Pointer movement and scroll from every sender go to the PC as
  they arrive.
- **Disconnect releases one sender.** When a sender's link drops, the dongle releases
  only what that sender held. Other senders' buttons and keys stay held.
- Bonding, the pairing window and the 10 s security timeout apply to each connection on
  its own. One new sender bonds per pairing window.
- The 3-bond limit covers all senders together.

Protocol version stays `1`: a version 1 sender cannot tell a multi-sender dongle from a
single-sender one.

## Byte order and types

All multi-byte fields are little-endian. `u8` is unsigned 8-bit; `i16` is signed 16-bit
two's complement.

## Packet header

Every packet starts with one header byte:

| Bits | Field | Meaning |
| --- | --- | --- |
| 0–3 | `version` | Protocol version. `1` for this spec. |
| 4–7 | `type` | Packet type. |

| `type` | Header byte (v1) | Packet |
| --- | --- | --- |
| 0 | `0x01` | [Pointer packet](#pointer-packet-type-0) |
| 1 | `0x11` | [Keyboard packet](#keyboard-packet-type-1) |
| 2–15 | | Reserved |

The dongle drops a packet whose `version` it does not know, or whose `type` is reserved,
and logs it in debug builds. It does not disconnect.

## Pointer packet (type 0)

9 bytes (legacy) or **11 bytes** (firmware 1.0+, adding horizontal scroll `hscroll`).

| Offset | Size | Field | Type | Meaning |
| --- | --- | --- | --- | --- |
| 0 | 1 | header | u8 | `0x01` (version 1, type 0) |
| 1 | 1 | `seq` | u8 | Increments by 1 per pointer packet, wraps 255 → 0. |
| 2 | 1 | `buttons` | u8 | Bitmask of buttons held **now**: bit 0 left, bit 1 right, bit 2 middle. Bits 3–7 are 0. |
| 3 | 2 | `dx` | i16 | Pointer movement since the last packet. Positive is right. |
| 5 | 2 | `dy` | i16 | Pointer movement since the last packet. Positive is down. |
| 7 | 2 | `vscroll` | i16 | Whole vertical scroll ticks since the last packet. Positive scrolls up (away from the user), as a mouse wheel does. |
| 9 | 2 | `hscroll` | i16 | *Optional (firmware 1.0+).* Whole horizontal scroll ticks (AC Pan) since the last packet. Positive scrolls right. Treated as `0` when omitted (9-byte packet). |

Example (11-byte): left button held, move right 3 and up 2, scroll down 1 tick and right 2 ticks, `seq` 7:

```
01 07 01 03 00 FE FF FF FF 02 00
```

Legacy 9-byte packets (`01 07 01 03 00 FE FF FF FF`) remain valid: firmware 1.0+ treats missing
bytes 9–10 as `hscroll = 0`, and pre-1.0 firmware ignores bytes 9–10 per the trailing-bytes rule.

### Rules for the phone

- **Buttons are state, not events.** Every packet carries the full button state. A lost
  packet cannot leave a button stuck, because the next packet corrects it.
- **Accumulate, never drop.** Pointer movement and scroll collected between send ticks are
  summed into the next packet. Fractions of a scroll tick stay on the phone until they add
  up to a whole tick.
- **One packet per send tick at most.** The send tick is 15 ms, the connection interval.
  The phone sends a packet only when it has movement, scroll, or a button change, and only
  when Core Bluetooth reports it can send a write without response
  (`canSendWriteWithoutResponse`). Otherwise the sums keep growing until the next tick.
- If a sum would overflow `i16`, the phone sends the clamped value now and keeps the rest
  for the next packet.

### Rules for the dongle

- Act on every packet as soon as it arrives.
- **Report split.** A USB mouse report carries movement of −127…127 per axis. When a
  packet holds more, the dongle sends several reports, each carrying up to 127 on each
  axis, until the packet is used up. Vertical scroll (`wheel`) and horizontal scroll (`pan`)
  each go out **one tick per report**, at the USB poll rate (1 ms), so a packet with
  `vscroll` 3 takes 3 ms. Senders keep scroll steps small per packet.
- **Button order.** Newly pressed buttons go out in a report with no movement before the
  packet's movement. Newly released buttons go out after it. A tap-then-drag therefore
  presses where the pointer was, and a drop releases where it ended.
- `seq` is for diagnosis only. A gap or repeat is logged in debug builds, and the packet is
  still applied.
- Trailing bytes after byte 11 (or after byte 9 on older firmware) are ignored, so later
  revisions can append fields without breaking version 1 dongles.

## Keyboard packet (type 1)

9 bytes. It carries the whole keyboard state, as the pointer packet carries the whole button
state.

| Offset | Size | Field | Type | Meaning |
| --- | --- | --- | --- | --- |
| 0 | 1 | header | u8 | `0x11` (version 1, type 1) |
| 1 | 1 | `seq` | u8 | Increments by 1 per keyboard packet, wraps 255 → 0. Pointer packets count their own. |
| 2 | 1 | `modifiers` | u8 | Modifiers held **now**, as in a USB boot keyboard report: bit 0 left Ctrl, 1 left Shift, 2 left Alt, 3 left GUI, 4 right Ctrl, 5 right Shift, 6 right Alt, 7 right GUI. |
| 3 | 6 | `keys` | u8 × 6 | Keys held **now**, as USB HID Keyboard page (0x07) usage IDs. `0` is an empty slot. Order does not matter. |

Example: Ctrl held with C (usage `0x06`), `seq` 4:

```
11 04 01 06 00 00 00 00 00
```

### Rules for the phone

- **Keys are state, not events**, as for buttons. Every keyboard packet carries every key
  and modifier held now; a key missing from it is released.
- **Every key change gets its own packet.** A tap is two packets: one with the key held,
  then one without it. The phone never merges them into one tick, so the PC always sees the
  key go down.
- At most 6 keys are held. A key pressed while 6 are held is not sent.
- The phone sends a keyboard packet only when the state changes. Keyboard and pointer
  packets share the send tick: at most one packet of each type per tick, the keyboard
  packet first.

### Rules for the dongle

- Act on every packet as soon as it arrives: send one USB keyboard report with exactly the
  packet's modifiers and keys.
- Keyboard and pointer packets go out in the order they arrived, so a key held before a
  move is down before the pointer moves.
- `seq`, trailing bytes and unknown versions follow the pointer packet's rules.

## Info characteristic

Read-only, 4 bytes, so the phone can check what it is talking to. Reading it needs an
encrypted link, so the read completes only after pairing or bond restore. The phone treats
a successful read as "link ready": from then on the dongle acts on its input packets. If
the dongle refuses the phone (outside the pairing window), it disconnects instead.

| Offset | Size | Field | Type | Meaning |
| --- | --- | --- | --- | --- |
| 0 | 1 | `protocol` | Highest protocol version the dongle understands (`1`). |
| 1 | 1 | `fw_major` | Firmware major version (`1`). |
| 2 | 1 | `fw_minor` | Firmware minor version (`0`). |
| 3 | 1 | `flags` | Bit 0: pairing window open. Bits 1–7 are 0. |

## Name characteristic

The dongle's name: what it advertises, what iOS shows as its Bluetooth name, and what its
screen shows. The USB device keeps the product name `Tocamatrol`.

- **Read:** the name, 1–20 bytes of printable ASCII (`0x20`–`0x7E`), no terminator.
- **Write (with response):** a new name. The dongle trims leading and trailing spaces,
  replaces any byte outside printable ASCII with `?`, and keeps the first 20 bytes. An
  empty result restores the default `Tocamatrol XXXX`. The name survives power-off. It is
  advertised from the next advertisement, since the dongle does not advertise when all
  connection slots are full.
- Writes need an encrypted link with a bonded phone, as for input.

## Connection parameters

After connecting, the dongle:

1. Keeps the sender's connection interval when it is 15 ms or faster. Otherwise the dongle
   requests 15 ms (min = max = 12 × 1.25 ms), peripheral latency 0, supervision timeout 2 s:
   the fastest interval Apple's accessory guidelines allow for a non-HID accessory. iOS may
   grant a slower one; the protocol works at any interval.
2. Requests the 2M PHY for both directions. A phone without 2M stays on 1M.
3. Accepts the phone's MTU exchange. Both 9-byte and 11-byte pointer packets fit the default 23-byte ATT MTU.

## Bonding

ADR 0002 records why. Pairing uses LE Secure Connections with "Just Works" association,
and both sides store the bond.

- **Pairing window.** The dongle accepts a new bond only for 60 s after power-up, or for
  60 s after a short press of its button. The status LED or screen shows when the window is open.
- **Security request.** Right after a phone connects, the dongle asks it to encrypt the
  link. An unpaired iPhone shows the "Bluetooth Pairing Request" sheet; a bonded one
  encrypts silently with its stored keys.
- **Outside the window**, a phone that completes pairing without an earlier bond has
  that new bond deleted and is disconnected.
- A link that is still unencrypted 10 s after connecting is disconnected, so a phone that
  never pairs cannot hold a connection slot.
- **Writes to the Input characteristic need an encrypted link** with a bonded phone. The
  dongle ignores input on an unencrypted link.
- **Forget all phones.** Holding the dongle's button for 5 s erases every stored bond and
  opens the pairing window. The phone must also forget the dongle in iOS Settings →
  Bluetooth before it can pair again.
- The dongle stores up to 3 bonds (a limit fixed in the ESP32 Arduino core). A new bond
  past that replaces the oldest.

## Disconnect

When a sender's link drops for any reason, the dongle at once releases every button and
key that sender held, so nothing stays pressed; other senders' input stays held (see
[Several senders](#several-senders)). It then advertises again if it was not already. The
phone reconnects automatically and starts its button and key state from "none held".
