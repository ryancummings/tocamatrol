# Tocamatrol

Tocamatrol turns an iPhone or iPad into a customizable macro pad and wireless trackpad. It
talks over bonded BLE to an ESP32-S3 dongle, which exposes itself to any PC, Mac, or Linux
machine as a standard USB HID mouse and keyboard with zero drivers or companion software.

## Layout

| Path | What |
| --- | --- |
| `protocol/PROTOCOL.md` | The BLE packet spec. Single source of truth: change it first, then `dongle/lib/toca_core/`, `ios/TocaCore/`, and `tools/send_test.py`. |
| `boards.json` | Declarative hardware catalog shared by firmware CI, the web flasher, and hardware docs. |
| `dongle/` | ESP32-S3 firmware: PlatformIO, Arduino framework, NimBLE-Arduino, TinyUSB HID. |
| `ios/` | SwiftUI app (iOS 17+), `TocaCore` Swift package, and `fastlane/` release & poster automation. `project.yml` is the XcodeGen spec; `.xcodeproj` is generated, not committed. |
| `web/` | Static Vite + React + TypeScript + Tailwind web flasher (`esptool-js`), hardware guide, pairing instructions, and privacy policy. |
| `tools/` | `make_app_icon.py` (native Liquid Glass `AppIcon.icon` generator), Python test sender (`bleak`), Linux HID watcher (`watch_hid.py`), and `promo_video/` (how-it-works scene: `npm run render` writes the video to `web/public/media/`; `npm run render:store` writes the App Store header and search videos to `ios/fastlane/creative/`; `ios/fastlane/creative_assets.py` renders the matching stills). |
| `GLOSSARY.md`, `docs/adr/` | Domain glossary and architecture decision records. |

## Rules

- Release firmware exposes USB HID mouse and keyboard interfaces only (ADR 0003). USB serial
  logging (`TOCA_DEBUG=1`) and optional vendor HID extensions (`TOCA_PC_CHANNEL=1`) are
  off in release builds.
- The dongle accepts input only from bonded senders (ADR 0002). Do not weaken this without
  a new ADR.
- Keep team IDs, App Store Connect credentials, and local signing files (`ios/LocalSigning.xcconfig`,
  `ios/fastlane/.env`) gitignored and out of committed files.
- Keep `boards.json` in sync with `dongle/platformio.ini` (`web/` Vitest enforces this).

## Agent docs

- Domain docs: `GLOSSARY.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
- Issue tracking & triage labels: `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`.
