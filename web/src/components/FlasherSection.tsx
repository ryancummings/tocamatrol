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
    <section id="flash" className="scroll-mt-20 border-t-2 border-ink-border py-14">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h2 className="font-display text-2xl tracking-tight text-ink sm:text-3xl">
            Flash your ESP32-S3 dongle from the browser
          </h2>
          <p className="mt-2 max-w-[65ch] text-sm leading-relaxed text-muted">
            Writes one merged factory image at offset <code className="font-mono font-bold text-accent-label">0x0</code>{" "}
            over Web Serial, verifies the chip is ESP32-S3, and checks SHA-256 before&nbsp;writing.
          </p>
        </div>
        {manifest && (
          <div className="rounded-lg border-2 border-pop-ink bg-yellow px-3 py-1.5 font-mono text-xs font-bold text-pop-ink shadow-[2px_2px_0_0_var(--color-ink-shadow)]">
            Firmware v{manifest.version}
          </div>
        )}
      </div>

      {!transport.isSupported && (
        <div
          role="status"
          data-impeccable-ignore="hard-offset-shadow"
          className="comic-panel mb-6 flex items-start gap-3 bg-raised/65 p-4 text-sm"
        >
          <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-accent-label" />
          <div>
            <p className="font-bold text-ink">Web Serial is unavailable in this browser</p>
            <p className="mt-1 max-w-[65ch] text-muted">
              Browser flashing requires desktop <strong>Chrome</strong>, <strong>Edge</strong>,{" "}
              <strong>Brave</strong>, or <strong>Opera</strong>. On Safari, Firefox, or mobile, download
              the <code className="font-mono font-bold">.bin</code> below or flash with{" "}
              <code className="font-mono font-bold">esptool</code>.
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <div className="min-w-0 space-y-3 lg:col-span-5">
          <p className="font-mono text-xs font-bold uppercase tracking-wider text-muted">1. Choose your board</p>
          <div className="space-y-2.5">
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
                  data-impeccable-ignore="hard-offset-shadow"
                  className={`w-full rounded-xl border-2 p-3.5 text-left transition ${
                    selected
                      ? "border-pop-ink bg-yellow text-pop-ink shadow-[4px_4px_0_0_var(--color-ink-shadow)]"
                      : "border-ink-border bg-surface text-ink shadow-[2px_2px_0_0_var(--color-ink-shadow)] hover:-translate-x-0.5 hover:-translate-y-0.5"
                  } disabled:opacity-60`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="font-bold">{item.name}</span>
                    {item.recommended && (
                      <span className="rounded border-2 border-pop-ink bg-surface px-2 py-0.5 font-mono text-[11px] font-bold uppercase tracking-wider text-ink">
                        Recommended
                      </span>
                    )}
                  </div>
                  <p className={`mt-1 text-xs ${selected ? "font-medium text-pop-ink/90" : "text-muted"}`}>
                    {item.usbConnector}
                  </p>
                </button>
              );
            })}
          </div>
        </div>

        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 overflow-hidden p-5 lg:col-span-7">
          <div className="flex flex-wrap items-start justify-between gap-3 border-b-2 border-hairline pb-4">
            <div>
              <p className="font-mono text-xs font-bold uppercase tracking-wider text-muted">2. Enter bootloader mode</p>
              <h3 className="mt-1 text-lg font-bold text-ink">{board.name}</h3>
            </div>
            <span className="inline-flex items-center gap-1.5 rounded-lg border-2 border-ink-border bg-well px-2.5 py-1 font-mono text-xs font-bold text-ink">
              <Cpu className="h-3.5 w-3.5 text-accent" />
              {board.chip}
            </span>
          </div>

          <ol className="mt-4 space-y-2.5 text-sm text-ink">
            {board.bootInstructions.map((step, idx) => (
              <li key={step} className="flex gap-3">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md border-2 border-pop-ink bg-yellow font-mono text-xs font-bold text-pop-ink">
                  {idx + 1}
                </span>
                <span>{step}</span>
              </li>
            ))}
          </ol>

          <div className="-mx-5 mt-5 border-y-2 border-ink-border bg-well p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="font-mono text-xs font-bold uppercase tracking-wider text-muted">3. Flash firmware</p>
                <p className="mt-0.5 font-mono text-xs text-muted">
                  {board.flashFilename}
                  {artifact && hasRealBinary
                    ? ` · ${(artifact.size / 1024).toFixed(0)} KB · sha256:${artifact.sha256.slice(0, 10)}…`
                    : " · build artifact pending CI release"}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2.5">
                {hasRealBinary && artifact && (
                  <a
                    href={`${baseUrl}${artifact.file}`}
                    download={board.flashFilename}
                    data-impeccable-ignore="hard-offset-shadow"
                    className="comic-btn-secondary inline-flex items-center gap-1.5 rounded-lg bg-surface px-3 py-2 text-xs font-bold text-ink"
                  >
                    <Download className="h-3.5 w-3.5" />
                    .bin
                  </a>
                )}
                <button
                  type="button"
                  disabled={!transport.isSupported || busy}
                  onClick={handleFlash}
                  data-impeccable-ignore="hard-offset-shadow"
                  className="comic-btn inline-flex items-center gap-2 rounded-lg bg-yellow px-4 py-2 text-sm font-bold text-pop-ink disabled:cursor-not-allowed disabled:opacity-45 disabled:shadow-none"
                >
                  <Usb className="h-4 w-4" />
                  {busy ? "Flashing..." : "Connect & Flash"}
                </button>
              </div>
            </div>

            {state.kind !== "idle" && (
              <div className="mt-4 border-t-2 border-hairline pt-4">
                {state.kind === "downloading" && (
                  <p className="font-mono text-xs font-bold text-accent-label">Downloading &amp; verifying SHA-256...</p>
                )}
                {state.kind === "connecting" && (
                  <p className="font-mono text-xs font-bold text-accent-label">
                    Waiting for serial port and ROM bootloader sync...
                  </p>
                )}
                {state.kind === "flashing" && (
                  <div>
                    <div className="flex items-center justify-between font-mono text-xs font-bold text-ink">
                      <span>Writing {state.board.shortName} flash...</span>
                      <span>{state.percent}%</span>
                    </div>
                    <div className="mt-2 h-3 overflow-hidden rounded-full border-2 border-ink-border bg-surface">
                      <div
                        className="h-full bg-yellow transition-all duration-150"
                        style={{ width: `${state.percent}%` }}
                      />
                    </div>
                  </div>
                )}
                {state.kind === "done" && (
                  <div className="flex items-start gap-2.5 text-sm text-ok">
                    <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0" />
                    <div>
                      <p className="font-bold">
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
                      <p className="font-bold">{state.message}</p>
                      <p className="mt-1 text-xs text-muted">{state.hint}</p>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-2 text-xs text-muted">
            <span className="min-w-0 break-all font-mono">
              CLI fallback:{" "}
              <code className="font-semibold text-ink">esptool --chip esp32s3 write-flash 0x0 {board.flashFilename}</code>
            </span>
            <button
              type="button"
              onClick={() => setShowLogs((v) => !v)}
              className="inline-flex items-center gap-1 font-mono font-bold text-accent hover:underline"
            >
              <Terminal className="h-3.5 w-3.5" />
              {showLogs ? "Hide log" : "Show log"}
            </button>
          </div>

          {showLogs && (
            <pre className="mt-3 max-h-48 overflow-auto border-t-2 border-hairline bg-ground p-3 font-mono text-xs text-ink">
              {logs.length > 0 ? logs.join("\n") : "No flasher output yet."}
            </pre>
          )}
        </div>
      </div>
    </section>
  );
}
