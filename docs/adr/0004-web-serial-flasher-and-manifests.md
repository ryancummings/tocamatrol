# Browser Web Serial flasher and merged 0x0 firmware manifests

Because release firmware has no USB serial port (ADR 0003) and users may not want to install
Python or PlatformIO just to flash an ESP32-S3 board, Tocamatrol ships a static Web Serial
flasher powered by `esptool-js` alongside a CI-generated `manifest.json` and one pre-merged
`0x0` factory binary per board defined in `boards.json`.

## Considered Options

- **PlatformIO / esptool CLI only**: requires installing Python toolchains and passing the
  exact multi-offset flash addresses (`0x0` bootloader, `0x8000` partitions, `0xe000`
  boot_app0, `0x10000` app), creating frequent user mistakes.
- **esp-web-tools widget**: fast to drop in, but hides chip-mismatch diagnostics and cannot
  easily share the same step-by-step BOOT guidance and console UI.

## Consequences

- Every supported board in `boards.json` produces a single `firmware-merged.bin` flashed at
  offset `0x0`, verified by SHA-256 before writing.
- The flasher explicitly checks the connected chip string and rejects non-ESP32-S3 boards
  (such as ESP32, ESP32-S2, ESP32-C3, and ESP32-C6) with an explanation before flashing.
- Safari and Firefox users without Web Serial get direct `.bin` downloads and a single-command
  `esptool` fallback.
