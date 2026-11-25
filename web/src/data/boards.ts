import catalog from "@root/boards.json";

export interface BoardSpec {
  id: string;
  name: string;
  shortName: string;
  chip: string;
  pioEnv: string;
  recommended: boolean;
  usbConnector: string;
  statusIndicator: string;
  pcPortNote: string;
  bootInstructions: string[];
  flashFilename: string;
  notes: string;
}

export interface IncompatibleChip {
  chip: string;
  hasUsbOtg: boolean;
  hasBle: boolean;
  reason: string;
}

export interface StatusGuideRow {
  state: string;
  screenText: string;
  ledPattern: string;
  meaning: string;
}

export const BOARDS: BoardSpec[] = catalog.boards;

export const INCOMPATIBLE_CHIPS: IncompatibleChip[] = [
  {
    chip: "ESP32",
    hasUsbOtg: false,
    hasBle: true,
    reason: "Classic ESP32 uses an external USB-UART chip only; cannot enumerate as a USB HID mouse or keyboard.",
  },
  {
    chip: "ESP32-S2",
    hasUsbOtg: true,
    hasBle: false,
    reason: "Has native USB-OTG, but lacks Bluetooth hardware completely.",
  },
  {
    chip: "ESP32-C3",
    hasUsbOtg: false,
    hasBle: true,
    reason: "USB port is fixed USB-Serial/JTAG only; no programmable USB-OTG HID.",
  },
  {
    chip: "ESP32-C6",
    hasUsbOtg: false,
    hasBle: true,
    reason: "USB port is fixed USB-Serial/JTAG only; no programmable USB-OTG HID.",
  },
  {
    chip: "ESP32-S3 (USB-UART bridge port only)",
    hasUsbOtg: true,
    hasBle: true,
    reason: "Board works only when your target computer plugs into the native USB-OTG port, not COM/UART.",
  },
];

export const STATUS_GUIDE: StatusGuideRow[] = [
  {
    state: "Pairing window open",
    screenText: "Pair now (countdown)",
    ledPattern: "Fast amber blink (dim amber on T-Dongle-S3)",
    meaning: "Open for 60 seconds after power-up or short BOOT press. Ready to pair a new iPhone or iPad.",
  },
  {
    state: "Waiting for bonded device",
    screenText: "Waiting",
    ledPattern: "Short blue flash once per second (dim blue on T-Dongle-S3)",
    meaning: "Advertising only to previously bonded iPhones/iPads. Press BOOT briefly to open pairing.",
  },
  {
    state: "Securing link",
    screenText: "Pairing...",
    ledPattern: "Fast green blink",
    meaning: "Encrypted handshake in progress. Accept the Bluetooth Pairing Request on iOS if shown.",
  },
  {
    state: "Connected & active",
    screenText: "Connected",
    ledPattern: "Steady green",
    meaning: "Encrypted link active; macros and trackpad input are sent to your computer.",
  },
];
