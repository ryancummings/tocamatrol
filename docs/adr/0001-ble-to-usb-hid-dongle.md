# The phone drives a USB HID dongle, not software on the PC

iOS cannot act as a Bluetooth HID mouse, and locked-down or managed PCs often prohibit
installing drivers or helper software. So the phone sends BLE packets to an ESP32-S3 dongle,
and the dongle presents itself as a standard USB mouse and keyboard, which Windows, macOS,
and Linux drive with built-in inbox drivers.

## Considered Options

- **Desktop helper over Wi-Fi**: requires software on the PC and a shared network. Fails on
  locked-down workstations and across isolated networks.
- **Phone as a Bluetooth HID peripheral**: iOS does not expose the HID peripheral role to
  third-party apps.

## Consequences

Everything the PC sees is decided by the dongle's USB descriptor. New HID capabilities (such
as horizontal scroll) require a protocol addition and a firmware update, not a PC software
install. Plugging an unapproved USB device into a managed PC may still fall under local IT
policy; the design removes the software problem, not that policy question.
