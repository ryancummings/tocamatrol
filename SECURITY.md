# Security Policy

## Threat model

Tocamatrol turns a paired iPhone or iPad into a USB keyboard and mouse on any computer the
ESP32-S3 dongle is plugged into:

- **Bonded BLE only ([ADR 0002](docs/adr/0002-bonded-phones-only.md))**: The dongle requires
  LE Secure Connections bonding and accepts new bonds only during an explicit 60-second
  pairing window (on boot or after pressing BOOT). Input packets on unencrypted or
  unbonded links are ignored.
- **HID-only USB ([ADR 0003](docs/adr/0003-hid-only-release-build.md))**: Release firmware
  exposes only standard USB HID mouse and keyboard interfaces (no USB serial port or mass
  storage).
- **On-device iOS storage**: Saved macros and pages are written with iOS
  `completeFileProtection` and optional Face ID / Touch ID / Passcode app lock. Nothing is
  sent to external servers or analytics services.

## Reporting a vulnerability

Please open a private GitHub Security Advisory on `ryancummings/tocamatrol` rather than
posting exploit details in a public issue. Include the firmware version, board model, iOS
version, and steps to reproduce.
