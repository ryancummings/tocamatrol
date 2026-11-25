import { ESPLoader, Transport } from "esptool-js";
import type { SerialSessionPort, SerialTransportPort } from "./types";

interface WebSerialPort {
  close(): Promise<void>;
}

interface WebSerialNavigator {
  serial?: {
    requestPort(): Promise<WebSerialPort>;
  };
}

class EsptoolSerialSession implements SerialSessionPort {
  private readonly transport: Transport;
  private readonly loader: ESPLoader;

  constructor(port: WebSerialPort, onLog: (line: string) => void) {
    this.transport = new Transport(port as never, false);
    this.loader = new ESPLoader({
      transport: this.transport,
      baudrate: 115200,
      romBaudrate: 115200,
      terminal: {
        clean: () => {},
        writeLine: (data: string) => onLog(data),
        write: (data: string) => {
          const trimmed = data.trimEnd();
          if (trimmed) onLog(trimmed);
        },
      },
    });
  }

  async connectAndIdentify(): Promise<string> {
    return await this.loader.main();
  }

  async flashMergedBinary(
    data: Uint8Array,
    address: number,
    onProgress: (written: number, total: number) => void,
  ): Promise<void> {
    await this.loader.writeFlash({
      fileArray: [{ data, address }],
      flashMode: "keep",
      flashFreq: "keep",
      flashSize: "keep",
      eraseAll: false,
      compress: true,
      reportProgress: (_fileIndex, written, total) => {
        onProgress(written, total);
      },
    });
    try {
      await this.loader.after("hard_reset");
    } catch {
      // Native USB-OTG ROM bootloader drops the serial port on reset; that's expected.
    }
  }

  async resetAndDisconnect(): Promise<void> {
    try {
      await this.transport.disconnect();
    } catch {
      // Ignore disconnect errors when the board has already reset out of bootloader mode.
    }
  }
}

export class WebSerialTransportAdapter implements SerialTransportPort {
  get isSupported(): boolean {
    if (typeof navigator === "undefined") return false;
    return Boolean((navigator as unknown as WebSerialNavigator).serial?.requestPort);
  }

  async openSession(onLog: (line: string) => void): Promise<SerialSessionPort> {
    const serial = (navigator as unknown as WebSerialNavigator).serial;
    if (!serial) {
      throw new Error("Web Serial is not available in this browser.");
    }
    const port = await serial.requestPort();
    return new EsptoolSerialSession(port, onLog);
  }
}
