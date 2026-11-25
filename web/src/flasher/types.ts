import type { BoardSpec } from "../data/boards";

export interface ManifestBoardArtifact {
  file: string;
  size: number;
  sha256: string;
}

export interface FirmwareManifest {
  version: string;
  builtAt: string;
  boards: Record<string, ManifestBoardArtifact>;
}

export type FlashErrorCode =
  | "UNSUPPORTED_BROWSER"
  | "MANIFEST_UNAVAILABLE"
  | "MISSING_BOARD_FIRMWARE"
  | "CHECKSUM_MISMATCH"
  | "WRONG_CHIP"
  | "BOOTLOADER_TIMEOUT"
  | "PORT_BUSY"
  | "FLASH_FAILED";

export type FlashState =
  | { kind: "idle" }
  | { kind: "downloading"; board: BoardSpec }
  | { kind: "connecting"; board: BoardSpec }
  | { kind: "flashing"; board: BoardSpec; percent: number; written: number; total: number }
  | { kind: "done"; board: BoardSpec; version: string }
  | { kind: "error"; code: FlashErrorCode; message: string; hint: string };

export interface FlashCallbacks {
  onState: (state: FlashState) => void;
  onLog: (line: string) => void;
}

export interface SerialSessionPort {
  connectAndIdentify(): Promise<string>;
  flashMergedBinary(
    data: Uint8Array,
    address: number,
    onProgress: (written: number, total: number) => void,
  ): Promise<void>;
  resetAndDisconnect(): Promise<void>;
}

export interface SerialTransportPort {
  readonly isSupported: boolean;
  openSession(onLog: (line: string) => void): Promise<SerialSessionPort>;
}

export interface ManifestFetcherPort {
  fetchManifest(): Promise<FirmwareManifest>;
  fetchBinary(path: string): Promise<Uint8Array>;
}
