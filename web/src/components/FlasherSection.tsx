import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  Cpu,
  Download,
  Terminal,
  Usb,
  XCircle,
} from "lucide-react";
import { BOARDS, type BoardSpec } from "../data/boards";
import { WebSerialTransportAdapter } from "../flasher/esptoolAdapter";
import { FirmwareFlasher, HttpManifestFetcher, isPlaceholderArtifact } from "../flasher/flasher";
import type { FirmwareManifest, FlashState } from "../flasher/types";

interface FlasherSectionProps {
  selectedBoardId: string;
  onSelectBoard: (id: string) => void;
}

export function FlasherSection({ selectedBoardId, onSelectBoard }: FlasherSectionProps) {
  const baseUrl = import.meta.env.BASE_URL ?? "/";
  const transport = useMemo(() => new WebSerialTransportAdapter(), []);
  const fetcher = useMemo(() => new HttpManifestFetcher(baseUrl), [baseUrl]);
  const flasher = useMemo(() => new FirmwareFlasher(transport, fetcher), [transport, fetcher]);

  const [manifest, setManifest] = useState<FirmwareManifest | null>(null);
  const [state, setState] = useState<FlashState>({ kind: "idle" });
  const [logs, setLogs] = useState<string[]>([]);
  const [showLogs, setShowLogs] = useState(false);

  const board: BoardSpec = BOARDS.find((b) => b.id === selectedBoardId) ?? BOARDS[0];
  const artifact = manifest?.boards[board.id];
  const hasRealBinary = Boolean(artifact && !isPlaceholderArtifact(artifact.sha256));
  const busy = state.kind === "downloading" || state.kind === "connecting" || state.kind === "flashing";

  useEffect(() => {
    let active = true;
    fetcher
      .fetchManifest()
      .then((m) => {
        if (active) setManifest(m);
      })
      .catch(() => {
        if (active) setManifest(null);
      });
    return () => {
      active = false;
    };
  }, [fetcher]);

  const appendLog = (line: string) => {
    setLogs((prev) => [...prev.slice(-150), line]);
  };

  const handleFlash = async () => {
    setLogs([]);
    await flasher.flash(board, {
      onState: setState,
      onLog: appendLog,
    });
  };

  return (
    <section id="flash" className="scroll-mt-20 border-t border-hairline py-14">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">// Web Flasher</p>
          <h2 className="mt-1 text-2xl font-semibold tracking-tight text-ink sm:text-3xl">
            Flash your ESP32-S3 dongle from the browser
          </h2>
          <p className="mt-2 max-w-2xl text-sm text-muted">
            Writes one merged factory image at offset <code className="font-mono text-amber-label">0x0</code>{" "}
            over Web Serial, verifies the chip is ESP32-S3, and checks SHA-256 before writing.
          </p>
        </div>
        {manifest && (
          <div className="rounded-md border border-hairline bg-surface px-3 py-2 font-mono text-xs text-muted">
            Firmware <span className="text-amber-label">v{manifest.version}</span>
          </div>
        )}
      </div>

      {!transport.isSupported && (
        <div
          role="status"
          className="mb-6 flex items-start gap-3 rounded-lg border border-amber/40 bg-amber/10 p-4 text-sm"
        >
          <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-amber" />
          <div>
            <p className="font-semibold text-amber-label">Web Serial is unavailable in this browser</p>
            <p className="mt-1 text-muted">
              Browser flashing requires desktop <strong>Chrome</strong>, <strong>Edge</strong>,{" "}
              <strong>Brave</strong>, or <strong>Opera</strong>. On Safari, Firefox, or mobile, download
              the <code className="font-mono">.bin</code> below or flash with{" "}
              <code className="font-mono">esptool</code>.
            </p>
          </div>
        </div>
      )}

      <div className="grid gap-6 lg:grid-cols-12">
        <div className="space-y-3 lg:col-span-5">
          <p className="font-mono text-xs uppercase tracking-wider text-dim">1. Choose your board</p>
          <div className="space-y-2">
            {BOARDS.map((item) => {
              const selected = item.id === board.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    onSelectBoard(item.id);
                    if (state.kind !== "idle") setState({ kind: "idle" });
                  }}
                  className={`w-full rounded-lg border p-3.5 text-left transition ${
                    selected
                      ? "border-amber bg-amber/10"
                      : "border-hairline bg-surface hover:border-strong"
                  } disabled:opacity-60`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-semibold text-ink">{item.name}</span>
                    {item.recommended && (
                      <span className="rounded border border-amber/50 bg-amber/15 px-1.5 py-0.5 font-mono text-[10px] uppercase tracking-wider text-amber-label">
                        Recommended
                      </span>
                    )}
                  </div>
                  <p className="mt-1 text-xs text-muted">{item.usbConnector}</p>
                </button>
              );
            })}
          </div>
        </div>

        <div className="rounded-xl border border-hairline bg-surface p-5 lg:col-span-7">
          <div className="flex flex-wrap items-start justify-between gap-3 border-b border-hairline pb-4">
            <div>
              <p className="font-mono text-xs uppercase tracking-wider text-dim">2. Enter bootloader mode</p>
              <h3 className="mt-1 text-lg font-semibold text-ink">{board.name}</h3>
            </div>
            <span className="inline-flex items-center gap-1.5 rounded border border-hairline bg-well px-2.5 py-1 font-mono text-xs text-muted">
              <Cpu className="h-3.5 w-3.5 text-amber" />
              {board.chip}
            </span>
          </div>

          <ol className="mt-4 space-y-2 text-sm text-ink/90">
            {board.bootInstructions.map((step, idx) => (
              <li key={step} className="flex gap-3">
                <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded bg-raised font-mono text-xs font-semibold text-amber-label">
                  {idx + 1}
                </span>
                <span>{step}</span>
              </li>
            ))}
          </ol>

          <div className="mt-5 rounded-lg border border-hairline bg-well p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="font-mono text-xs uppercase tracking-wider text-dim">3. Flash firmware</p>
                <p className="mt-0.5 font-mono text-xs text-muted">
                  {board.flashFilename}
                  {artifact && hasRealBinary
                    ? ` · ${(artifact.size / 1024).toFixed(0)} KB · sha256:${artifact.sha256.slice(0, 10)}…`
                    : " · build artifact pending CI release"}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                {hasRealBinary && artifact && (
                  <a
                    href={`${baseUrl}${artifact.file}`}
                    download={board.flashFilename}
                    className="inline-flex items-center gap-1.5 rounded-md border border-hairline bg-surface px-3 py-2 text-xs font-semibold text-ink hover:border-strong"
                  >
                    <Download className="h-3.5 w-3.5" />
                    .bin
                  </a>
                )}
                <button
                  type="button"
                  disabled={!transport.isSupported || busy}
                  onClick={handleFlash}
                  className="inline-flex items-center gap-2 rounded-md border border-amber bg-amber px-4 py-2 text-sm font-semibold text-ground transition hover:brightness-110 disabled:cursor-not-allowed disabled:opacity-45"
                >
                  <Usb className="h-4 w-4" />
                  {busy ? "Flashing..." : "Connect & Flash"}
                </button>
              </div>
            </div>

            {state.kind !== "idle" && (
              <div className="mt-4 border-t border-hairline pt-4">
                {state.kind === "downloading" && (
                  <p className="font-mono text-xs text-amber-label">Downloading &amp; verifying SHA-256...</p>
                )}
                {state.kind === "connecting" && (
                  <p className="font-mono text-xs text-amber-label">
                    Waiting for serial port and ROM bootloader sync...
                  </p>
                )}
                {state.kind === "flashing" && (
                  <div>
                    <div className="flex items-center justify-between font-mono text-xs text-amber-label">
                      <span>Writing {state.board.shortName} flash...</span>
                      <span>{state.percent}%</span>
                    </div>
                    <div className="mt-2 h-2 overflow-hidden rounded-full bg-raised">
                      <div
                        className="h-full bg-amber transition-all duration-150"
                        style={{ width: `${state.percent}%` }}
                      />
                    </div>
                  </div>
                )}
                {state.kind === "done" && (
                  <div className="flex items-start gap-2.5 text-sm text-ok">
                    <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0" />
                    <div>
                      <p className="font-semibold">
                        Flashed {state.board.name} (v{state.version})
                      </p>
                      <p className="mt-1 text-xs text-muted">{state.board.pcPortNote}</p>
                    </div>
                  </div>
                )}
                {state.kind === "error" && (
                  <div className="flex items-start gap-2.5 text-sm text-bad">
                    <XCircle className="mt-0.5 h-5 w-5 shrink-0" />
                    <div>
                      <p className="font-semibold">{state.message}</p>
                      <p className="mt-1 text-xs text-muted">{state.hint}</p>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-2 text-xs text-dim">
            <span className="font-mono">
              CLI fallback:{" "}
              <code className="text-muted">esptool --chip esp32s3 write-flash 0x0 {board.flashFilename}</code>
            </span>
            <button
              type="button"
              onClick={() => setShowLogs((v) => !v)}
              className="inline-flex items-center gap-1 font-mono text-muted hover:text-amber-label"
            >
              <Terminal className="h-3.5 w-3.5" />
              {showLogs ? "Hide log" : "Show log"}
            </button>
          </div>

          {showLogs && (
            <pre className="mt-3 max-h-48 overflow-auto rounded-md border border-hairline bg-ground p-3 font-mono text-xs text-muted">
              {logs.length > 0 ? logs.join("\n") : "No flasher output yet."}
            </pre>
          )}
        </div>
      </div>
    </section>
  );
}
