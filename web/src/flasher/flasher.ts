import type { BoardSpec } from "../data/boards";
import type {
  FlashCallbacks,
  FlashErrorCode,
  FlashState,
  FirmwareManifest,
  ManifestFetcherPort,
  SerialSessionPort,
  SerialTransportPort,
} from "./types";

export async function computeSha256Hex(data: Uint8Array): Promise<string> {
  const copy = new Uint8Array(data.byteLength);
  copy.set(data);
  const digest = await globalThis.crypto.subtle.digest("SHA-256", copy.buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function isPlaceholderArtifact(sha256: string): boolean {
  return !/^[a-f0-9]{64}$/i.test(sha256) || /^0+$/.test(sha256);
}

export function classifyFlashError(err: unknown): {
  cancelled?: boolean;
  code: FlashErrorCode;
  message: string;
  hint: string;
} {
  const name = err instanceof Error ? err.name : "";
  const msg = err instanceof Error ? err.message : String(err);

  if (name === "NotFoundError") {
    return {
      cancelled: true,
      code: "FLASH_FAILED",
      message: "Cancelled",
      hint: "",
    };
  }

  if (name === "NetworkError" || /already open|in use|failed to open/i.test(msg)) {
    return {
      code: "PORT_BUSY",
      message: "Could not open the serial port.",
      hint: "Close PlatformIO, Arduino IDE, or another browser tab using this device, then try again.",
    };
  }

  if (/timed out|packet header|failed to connect|wrong boot mode|invalid head/i.test(msg)) {
    return {
      code: "BOOTLOADER_TIMEOUT",
      message: "The board did not respond in ROM bootloader mode.",
      hint: "Unplug the dongle, hold the BOOT button while plugging it back in, release BOOT, and try again.",
    };
  }

  return {
    code: "FLASH_FAILED",
    message: msg || "Flashing failed unexpectedly.",
    hint: "Use a data-capable USB cable (not a charge-only cable), re-enter BOOT mode, and retry.",
  };
}

export class HttpManifestFetcher implements ManifestFetcherPort {
  constructor(private readonly baseUrl: string) {}

  async fetchManifest(): Promise<FirmwareManifest> {
    const url = `${this.baseUrl}firmware/manifest.json`;
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} while loading ${url}`);
    }
    return (await response.json()) as FirmwareManifest;
  }

  async fetchBinary(path: string): Promise<Uint8Array> {
    const cleanPath = path.replace(/^\/+/, "");
    const response = await fetch(`${this.baseUrl}${cleanPath}`, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status} while downloading ${cleanPath}`);
    }
    return new Uint8Array(await response.arrayBuffer());
  }
}

export class FirmwareFlasher {
  constructor(
    private readonly transport: SerialTransportPort,
    private readonly fetcher: ManifestFetcherPort,
  ) {}

  async flash(board: BoardSpec, callbacks: FlashCallbacks): Promise<FlashState> {
    const emit = (state: FlashState): FlashState => {
      callbacks.onState(state);
      return state;
    };

    if (!this.transport.isSupported) {
      return emit({
        kind: "error",
        code: "UNSUPPORTED_BROWSER",
        message: "Web Serial is not supported in this browser.",
        hint: "Use Chrome, Edge, or Brave on a desktop computer, or download the .bin file and flash with esptool.",
      });
    }

    emit({ kind: "downloading", board });
    callbacks.onLog(`Fetching manifest for ${board.name}...`);

    let manifest: FirmwareManifest;
    try {
      manifest = await this.fetcher.fetchManifest();
    } catch (err) {
      return emit({
        kind: "error",
        code: "MANIFEST_UNAVAILABLE",
        message: err instanceof Error ? err.message : "Could not load firmware manifest.",
        hint: "Download prebuilt firmware from GitHub Releases or check your network connection.",
      });
    }

    const artifact = manifest.boards[board.id];
    if (!artifact || isPlaceholderArtifact(artifact.sha256)) {
      return emit({
        kind: "error",
        code: "MISSING_BOARD_FIRMWARE",
        message: `No compiled binary is published in this build for ${board.name}.`,
        hint: "In local development, run CI or copy firmware-merged.bin files into web/public/firmware/.",
      });
    }

    let binary: Uint8Array;
    try {
      callbacks.onLog(`Downloading ${artifact.file}...`);
      binary = await this.fetcher.fetchBinary(artifact.file);
    } catch (err) {
      return emit({
        kind: "error",
        code: "MANIFEST_UNAVAILABLE",
        message: err instanceof Error ? err.message : "Failed to download firmware binary.",
        hint: "Reload the page and try again, or flash using the GitHub Release asset.",
      });
    }

    const actualSha = await computeSha256Hex(binary);
    if (actualSha.toLowerCase() !== artifact.sha256.toLowerCase()) {
      return emit({
        kind: "error",
        code: "CHECKSUM_MISMATCH",
        message: `SHA-256 verification failed for ${artifact.file}.`,
        hint: "Refusing to flash a corrupted download. Reload and retry.",
      });
    }
    callbacks.onLog(`Verified SHA-256 (${actualSha.slice(0, 12)}...)`);

    let session: SerialSessionPort | null = null;
    try {
      emit({ kind: "connecting", board });
      callbacks.onLog("Waiting for serial port selection...");
      session = await this.transport.openSession(callbacks.onLog);

      callbacks.onLog("Connecting to ESP32-S3 bootloader...");
      const detectedChip = await session.connectAndIdentify();
      callbacks.onLog(`Detected chip: ${detectedChip}`);

      if (!detectedChip.toUpperCase().includes("ESP32-S3")) {
        await session.resetAndDisconnect();
        session = null;
        return emit({
          kind: "error",
          code: "WRONG_CHIP",
          message: `Connected board is ${detectedChip}, not ESP32-S3.`,
          hint: "Tocamatrol requires an ESP32-S3 for both BLE and native USB-OTG HID. ESP32, ESP32-S2, ESP32-C3, and ESP32-C6 are not supported.",
        });
      }

      emit({ kind: "flashing", board, percent: 0, written: 0, total: binary.byteLength });
      callbacks.onLog(`Flashing ${binary.byteLength} bytes at 0x0...`);
      await session.flashMergedBinary(binary, 0x0, (written, total) => {
        const safeTotal = Math.max(total, 1);
        const percent = Math.min(100, Math.round((written / safeTotal) * 100));
        emit({ kind: "flashing", board, percent, written, total: safeTotal });
      });

      callbacks.onLog("Flash complete. Resetting device...");
      await session.resetAndDisconnect();
      session = null;

      return emit({ kind: "done", board, version: manifest.version });
    } catch (err) {
      if (session) {
        try {
          await session.resetAndDisconnect();
        } catch {
          // Best-effort cleanup after an error.
        }
      }
      const classified = classifyFlashError(err);
      if (classified.cancelled) {
        callbacks.onLog("Serial port selection cancelled.");
        return emit({ kind: "idle" });
      }
      callbacks.onLog(`Error: ${classified.message}`);
      return emit({
        kind: "error",
        code: classified.code,
        message: classified.message,
        hint: classified.hint,
      });
    }
  }
}
