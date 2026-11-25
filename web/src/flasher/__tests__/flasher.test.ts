import { createHash } from "node:crypto";
import { describe, expect, it, vi } from "vitest";
import { BOARDS } from "../../data/boards";
import { FirmwareFlasher } from "../flasher";
import type { FirmwareManifest, ManifestFetcherPort, SerialSessionPort, SerialTransportPort } from "../types";

const sampleBinary = new Uint8Array([0xe9, 0x05, 0x02, 0x20, 0x10, 0x20, 0x30, 0x40]);
const sampleSha256 = createHash("sha256").update(sampleBinary).digest("hex");

function makeManifest(overrides?: Partial<FirmwareManifest>): FirmwareManifest {
  const artifacts: FirmwareManifest["boards"] = {};
  for (const b of BOARDS) {
    artifacts[b.id] = {
      file: `firmware/${b.flashFilename}`,
      size: sampleBinary.byteLength,
      sha256: sampleSha256,
    };
  }
  return {
    version: "1.0.0",
    builtAt: "2026-11-25T15:00:00Z",
    boards: artifacts,
    ...overrides,
  };
}

class FakeFetcher implements ManifestFetcherPort {
  constructor(
    private readonly manifest: FirmwareManifest,
    private readonly binary: Uint8Array = sampleBinary,
  ) {}

  async fetchManifest(): Promise<FirmwareManifest> {
    return this.manifest;
  }

  async fetchBinary(): Promise<Uint8Array> {
    return this.binary;
  }
}

class FakeSession implements SerialSessionPort {
  flashedAddress: number | null = null;
  flashedBytes: Uint8Array | null = null;
  disconnected = false;

  constructor(
    private readonly chipName: string = "ESP32-S3",
    private readonly failConnect?: Error,
  ) {}

  async connectAndIdentify(): Promise<string> {
    if (this.failConnect) throw this.failConnect;
    return this.chipName;
  }

  async flashMergedBinary(
    data: Uint8Array,
    address: number,
    onProgress: (written: number, total: number) => void,
  ): Promise<void> {
    this.flashedAddress = address;
    this.flashedBytes = data;
    onProgress(Math.floor(data.byteLength / 2), data.byteLength);
    onProgress(data.byteLength, data.byteLength);
  }

  async resetAndDisconnect(): Promise<void> {
    this.disconnected = true;
  }
}

class FakeTransport implements SerialTransportPort {
  constructor(
    public readonly isSupported: boolean,
    private readonly sessionOrError: SerialSessionPort | Error,
  ) {}

  async openSession(): Promise<SerialSessionPort> {
    if (this.sessionOrError instanceof Error) {
      throw this.sessionOrError;
    }
    return this.sessionOrError;
  }
}

describe("FirmwareFlasher", () => {
  const board = BOARDS[0];

  it("reports unsupported when Web Serial is unavailable", async () => {
    const flasher = new FirmwareFlasher(
      new FakeTransport(false, new FakeSession()),
      new FakeFetcher(makeManifest()),
    );

    const states: string[] = [];
    await flasher.flash(board, { onState: (s) => states.push(s.kind), onLog: () => {} });

    expect(states[states.length - 1]).toBe("error");
    const final = await flasher.flash(board, { onState: () => {}, onLog: () => {} });
    expect(final.kind).toBe("error");
    if (final.kind === "error") {
      expect(final.code).toBe("UNSUPPORTED_BROWSER");
    }
  });

  it("verifies SHA-256, checks ESP32-S3, flashes at 0x0, and closes the port", async () => {
    const session = new FakeSession("ESP32-S3");
    const flasher = new FirmwareFlasher(
      new FakeTransport(true, session),
      new FakeFetcher(makeManifest()),
    );

    const states: string[] = [];
    const percents: number[] = [];
    const result = await flasher.flash(board, {
      onState: (s) => {
        states.push(s.kind);
        if (s.kind === "flashing") percents.push(s.percent);
      },
      onLog: () => {},
    });

    expect(result.kind).toBe("done");
    expect(states).toEqual([
      "downloading",
      "connecting",
      "flashing",
      "flashing",
      "flashing",
      "done",
    ]);
    expect(percents).toEqual([0, 50, 100]);
    expect(session.flashedAddress).toBe(0);
    expect(session.flashedBytes).toEqual(sampleBinary);
    expect(session.disconnected).toBe(true);
  });

  it("aborts before touching serial if SHA-256 checksum mismatches", async () => {
    const session = new FakeSession("ESP32-S3");
    const openSpy = vi.fn(async () => session);
    const transport: SerialTransportPort = { isSupported: true, openSession: openSpy };
    const badManifest = makeManifest();
    badManifest.boards[board.id].sha256 = "f".repeat(64);

    const flasher = new FirmwareFlasher(transport, new FakeFetcher(badManifest));
    const result = await flasher.flash(board, { onState: () => {}, onLog: () => {} });

    expect(openSpy).not.toHaveBeenCalled();
    expect(result.kind).toBe("error");
    if (result.kind === "error") {
      expect(result.code).toBe("CHECKSUM_MISMATCH");
    }
  });

  it("rejects non-ESP32-S3 boards before flashing and disconnects cleanly", async () => {
    const session = new FakeSession("ESP32-C3");
    const flasher = new FirmwareFlasher(
      new FakeTransport(true, session),
      new FakeFetcher(makeManifest()),
    );

    const result = await flasher.flash(board, { onState: () => {}, onLog: () => {} });

    expect(session.flashedBytes).toBeNull();
    expect(session.disconnected).toBe(true);
    expect(result.kind).toBe("error");
    if (result.kind === "error") {
      expect(result.code).toBe("WRONG_CHIP");
      expect(result.message).toContain("ESP32-C3");
    }
  });

  it("returns cleanly to idle when the user cancels the serial port picker", async () => {
    const abortErr = Object.assign(new Error("No port selected by the user."), { name: "NotFoundError" });
    const flasher = new FirmwareFlasher(
      new FakeTransport(true, abortErr),
      new FakeFetcher(makeManifest()),
    );

    const result = await flasher.flash(board, { onState: () => {}, onLog: () => {} });
    expect(result.kind).toBe("idle");
  });

  it("maps bootloader sync failures to BOOT-mode recovery guidance", async () => {
    const session = new FakeSession("ESP32-S3", new Error("Failed to connect to ESP32: Timed out waiting for packet header"));
    const flasher = new FirmwareFlasher(
      new FakeTransport(true, session),
      new FakeFetcher(makeManifest()),
    );

    const result = await flasher.flash(board, { onState: () => {}, onLog: () => {} });

    expect(session.disconnected).toBe(true);
    expect(result.kind).toBe("error");
    if (result.kind === "error") {
      expect(result.code).toBe("BOOTLOADER_TIMEOUT");
      expect(result.hint).toContain("BOOT");
    }
  });
});
