# Tocamatrol

An iPhone or iPad used as a customizable macro pad and wireless trackpad for a PC it never
installs anything on. The phone sends input over Bluetooth LE to an ESP32-S3 dongle, and
the dongle presents itself to the PC as an ordinary USB mouse and keyboard.

## Devices

**Phone**:
The iPhone or iPad running the Tocamatrol app.
_Avoid_: client, controller, remote

**Dongle**:
The ESP32-S3 stick plugged into the PC. It turns packets from the phone into USB mouse and
keyboard reports.
_Avoid_: receiver, bridge, adapter, device

**PC**:
Any Windows, macOS, or Linux computer the dongle is plugged into. It sees only a standard
USB mouse and keyboard.
_Avoid_: host, workstation, target

## Link

**Packet**:
One message from phone to dongle, as defined in `protocol/PROTOCOL.md`.
_Avoid_: frame, message, report

**Report**:
One USB HID input report from dongle to PC. One packet can become several reports.
_Avoid_: packet, event

**Report split**:
Breaking one packet's movement or scroll into several reports because each report can
carry only a small step.
_Avoid_: chunking, fragmentation

**Send tick**:
The fixed interval at which the phone may send at most one packet of each type. Input
between ticks is accumulated, never dropped.
_Avoid_: frame, poll

**Bonded phone**:
A phone that has paired with the dongle and whose keys the dongle has stored. Only bonded
phones can send input.
_Avoid_: paired device, trusted device

**Pairing window**:
The short period after power-up or a button press during which the dongle accepts a new
phone.
_Avoid_: pairing mode, discoverable mode

## Macro Pad

**Macro pad**:
The phone's button surface: user-arranged pages of customizable macro buttons.
_Avoid_: keypad, shortcut panel, workflows panel

**Page**:
A named screen on the macro pad arranged as a configurable grid of macro buttons and empty
sockets.
_Avoid_: tab, layer, profile, custom page

**Grid**:
A page's columns-by-rows layout dimensions.
_Avoid_: board, matrix

**Button span**:
How many columns and rows a macro button occupies on a page's grid.
_Avoid_: footprint, block, tile size

**Starter page**:
The editable example page created automatically on first launch when no saved library exists.
_Avoid_: default layout, built-in page

**Macro**:
A named sequence of typed text, keyboard shortcuts, pauses, and recorded keystrokes that
plays on the PC when its button is pressed.
_Avoid_: script, workflow

**Virtual keyboard**:
The on-screen PC keyboard used to record raw key sequences into a macro.
_Avoid_: soft keyboard (the iOS system keyboard)

**Latched modifier**:
Ctrl, Shift, Alt, or Win/Cmd tapped on its own on the virtual keyboard: it stays down for
the next key, or until tapped again.
_Avoid_: sticky key, locked modifier

**Macro speed**:
How fast a macro plays: 1×, 2×, or 4× divides its pauses; Instant leaves pauses out.
_Avoid_: acceleration (that belongs to the pointer and scroll)

## Trackpad

**Trackpad**:
The phone's touch surface mode: moves the pointer, clicks, drags, and scrolls in two dimensions.
_Avoid_: touchpad, touch area

**Pointer acceleration**:
The mapping from finger speed on the trackpad to how far each millimetre of finger travel
moves the pointer. Slow movement places the pointer precisely; a fast swipe crosses screens.
_Avoid_: sensitivity (pointer speed is the overall multiplier on top of it)

**Scroll acceleration**:
The same mapping for two-finger scroll: slow fingers step precisely, fast swipes fly through
long documents.
_Avoid_: rate curve

**Coast**:
Two-finger scroll that carries on smoothly after a flick, slowing to a stop, until a finger
touches the trackpad again.
_Avoid_: momentum, inertia, free spin

**Palm**:
A contact too large to be a fingertip. The trackpad ignores it for as long as it stays down.
_Avoid_: rejected touch

**Scroll tick**:
One whole step of the PC's vertical or horizontal mouse wheel. Fractions of a tick stay on
the phone until they add up to a whole one.
_Avoid_: notch, line, click

## Firmware Distribution

**Web flasher**:
The browser-based installer that writes Tocamatrol firmware to a supported ESP32-S3 board
over Web Serial without installing desktop flashing tools.
_Avoid_: web installer, updater

**Firmware manifest**:
The JSON descriptor listing each supported board's merged factory binary path and SHA-256
checksum for the web flasher.
_Avoid_: catalog, release index
