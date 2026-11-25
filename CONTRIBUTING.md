# Contributing to Tocamatrol

Thanks for helping improve Tocamatrol!

## Repository layout

- `protocol/PROTOCOL.md`: BLE packet specification (change first before modifying encoders/decoders).
- `boards.json`: Declarative hardware catalog shared by firmware CI, the web flasher, and hardware docs.
- `dongle/`: ESP32-S3 firmware (PlatformIO, Arduino, NimBLE-Arduino, TinyUSB HID) + native C++ logic tests (`lib/toca_core`).
- `ios/TocaCore/`: Pure Swift logic package (`swift test` runs on macOS and Linux).
- `ios/Tocamatrol/`: SwiftUI iOS/iPadOS app generated via `xcodegen generate`.
- `web/`: Vite + React + TypeScript + Tailwind static site & Web Serial flasher (`esptool-js`).
- `tools/`: Python BLE test sender (`send_test.py`), Linux HID watcher (`watch_hid.py`), and icon script.

## Running tests locally

```sh
# Swift logic package
cd ios/TocaCore && swift test

# Native firmware decoder & report-planning tests (requires PlatformIO)
cd dongle && pio test -e native

# Build all release firmware boards + merged factory binaries
cd dongle && pio run

# Web flasher & hardware guide (also validates boards.json vs platformio.ini)
cd web && npm ci && npm run lint && npx vitest run && npm run build

# Python packet encoder self-test
uv run tools/send_test.py --selftest
```

## Building the iOS app on your own Apple ID

1. Copy `ios/LocalSigning.xcconfig.example` to `ios/LocalSigning.xcconfig` (gitignored) and set your `DEVELOPMENT_TEAM`.
2. Generate the Xcode project:
   ```sh
   cd ios && xcodegen generate && open Tocamatrol.xcodeproj
   ```
3. Or build unsigned from the CLI:
   ```sh
   xcodebuild -project ios/Tocamatrol.xcodeproj -scheme Tocamatrol -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
   ```

## Adding support for a new ESP32-S3 board

1. Verify the board uses an **ESP32-S3** chip (both BLE and native USB-OTG HID are required).
2. Add a `#elif defined(TOCA_BOARD_...)` pin block in `dongle/include/board_config.h`.
3. Add release and debug `[env:...]` entries in `dongle/platformio.ini` and add the release env to `default_envs`.
4. Add the board entry to `boards.json`. The `web/` Vitest suite checks that every `boards.json` entry matches `dongle/platformio.ini`.
5. Run `cd dongle && pio run` and `cd web && npx vitest run`.
