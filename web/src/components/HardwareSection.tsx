import { Check, Cpu, X } from "lucide-react";
import { BOARDS, INCOMPATIBLE_CHIPS } from "../data/boards";

interface HardwareSectionProps {
  onPickBoardForFlash: (id: string) => void;
}

export function HardwareSection({ onPickBoardForFlash }: HardwareSectionProps) {
  return (
    <section id="hardware" className="scroll-mt-20 border-t border-hairline py-14">
      <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">// Compatible USB Devices</p>
      <h2 className="mt-1 text-2xl font-semibold tracking-tight text-ink sm:text-3xl">
        Which USB hardware works with Tocamatrol?
      </h2>
      <p className="mt-2 max-w-3xl text-sm leading-relaxed text-muted">
        Tocamatrol requires an <strong className="text-ink">ESP32-S3</strong> microcontroller. The dongle needs{" "}
        <strong className="text-ink">Bluetooth Low Energy</strong> to talk to your iPhone or iPad and{" "}
        <strong className="text-ink">native USB-OTG</strong> to enumerate as a standard USB HID mouse and
        keyboard with zero drivers on Windows, macOS, and Linux.
      </p>

      <div className="mt-8 grid gap-4 md:grid-cols-2">
        {BOARDS.map((board) => (
          <article
            key={board.id}
            className="flex flex-col justify-between rounded-xl border border-hairline bg-surface p-5"
          >
            <div>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-lg font-semibold text-ink">{board.name}</h3>
                {board.recommended && (
                  <span className="rounded border border-amber/50 bg-amber/15 px-2 py-0.5 font-mono text-[10px] uppercase tracking-wider text-amber-label">
                    Recommended
                  </span>
                )}
              </div>
              <p className="mt-2 text-sm text-muted">{board.notes}</p>
              <dl className="mt-4 space-y-2 border-t border-hairline pt-3 text-xs">
                <div className="flex justify-between gap-4">
                  <dt className="font-mono uppercase text-dim">USB Plug</dt>
                  <dd className="text-right text-ink">{board.usbConnector}</dd>
                </div>
                <div className="flex justify-between gap-4">
                  <dt className="font-mono uppercase text-dim">Status Indicator</dt>
                  <dd className="text-right text-ink">{board.statusIndicator}</dd>
                </div>
                <div className="flex justify-between gap-4">
                  <dt className="font-mono uppercase text-dim">Target PC Port</dt>
                  <dd className="text-right text-ink">{board.pcPortNote}</dd>
                </div>
              </dl>
            </div>
            <div className="mt-4 flex items-center justify-between border-t border-hairline pt-3">
              <span className="font-mono text-xs text-dim">env: {board.pioEnv}</span>
              <a
                href="#flash"
                onClick={() => onPickBoardForFlash(board.id)}
                className="font-mono text-xs font-semibold text-amber-label hover:underline"
              >
                Flash {board.shortName} →
              </a>
            </div>
          </article>
        ))}
      </div>

      <div className="mt-10 rounded-xl border border-hairline bg-surface p-5">
        <div className="flex items-center gap-2">
          <Cpu className="h-4 w-4 text-bad" />
          <h3 className="text-base font-semibold text-ink">Boards and chips that will NOT work</h3>
        </div>
        <p className="mt-1 text-sm text-muted">
          Other Espressif chips share similar names on store listings, but lack one of the two hardware blocks:
        </p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[540px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-hairline font-mono text-xs uppercase text-dim">
                <th className="py-2 pr-4">Chip</th>
                <th className="py-2 pr-4">BLE</th>
                <th className="py-2 pr-4">Native USB-OTG</th>
                <th className="py-2">Why</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline/60">
              <tr className="bg-ok/5">
                <td className="py-2.5 pr-4 font-mono font-semibold text-ok">ESP32-S3</td>
                <td className="py-2.5 pr-4 text-ok">
                  <Check className="inline h-4 w-4" />
                </td>
                <td className="py-2.5 pr-4 text-ok">
                  <Check className="inline h-4 w-4" />
                </td>
                <td className="py-2.5 text-ink">Supported. Runs both BLE and USB HID mouse + keyboard.</td>
              </tr>
              {INCOMPATIBLE_CHIPS.map((row) => (
                <tr key={row.chip}>
                  <td className="py-2.5 pr-4 font-mono text-ink">{row.chip}</td>
                  <td className="py-2.5 pr-4">
                    {row.hasBle ? (
                      <Check className="inline h-4 w-4 text-ok" />
                    ) : (
                      <X className="inline h-4 w-4 text-bad" />
                    )}
                  </td>
                  <td className="py-2.5 pr-4">
                    {row.hasUsbOtg ? (
                      <Check className="inline h-4 w-4 text-ok" />
                    ) : (
                      <X className="inline h-4 w-4 text-bad" />
                    )}
                  </td>
                  <td className="py-2.5 text-muted">{row.reason}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
