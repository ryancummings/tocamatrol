import { Check, Cpu, ShoppingCart, X } from "lucide-react";
import { AMAZON_DISCLOSURE, BOARDS, INCOMPATIBLE_CHIPS, amazonBuyUrl } from "../data/boards";

interface HardwareSectionProps {
  onPickBoardForFlash: (id: string) => void;
}

export function HardwareSection({ onPickBoardForFlash }: HardwareSectionProps) {
  return (
    <section id="hardware" className="scroll-mt-20 border-t-2 border-ink-border py-14">
      <h2 className="font-display text-2xl tracking-tight text-ink sm:text-3xl">
        Which USB hardware works with Tocamatrol?
      </h2>
      <p className="mt-2 max-w-[65ch] text-sm leading-relaxed text-muted">
        Tocamatrol requires an <strong className="text-ink">ESP32-S3</strong> microcontroller. The dongle needs{" "}
        <strong className="text-ink">Bluetooth Low Energy</strong> to talk to your iPhone or iPad and{" "}
        <strong className="text-ink">native USB-OTG</strong> to enumerate as a standard USB HID mouse and
        keyboard with zero drivers on Windows, macOS, and&nbsp;Linux.
      </p>
      <p className="mt-2 max-w-[65ch] text-xs text-dim">
        Buy links go to Amazon. {AMAZON_DISCLOSURE}
      </p>

      <div className="mt-8 grid grid-cols-1 gap-5 md:grid-cols-2">
        {BOARDS.map((board) => (
          <article key={board.id} data-impeccable-ignore="hard-offset-shadow" className="comic-panel flex min-w-0 flex-col justify-between p-5">
            <div>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <h3 className="text-lg font-bold text-ink">{board.name}</h3>
                {board.recommended && (
                  <span className="rounded-md border-2 border-pop-ink bg-yellow px-2 py-0.5 font-mono text-[11px] font-bold uppercase tracking-wider text-pop-ink">
                    Recommended
                  </span>
                )}
              </div>
              <p className="mt-2 max-w-[60ch] text-sm text-muted">{board.notes}</p>
              <dl className="mt-4 space-y-2 border-t-2 border-hairline pt-3 text-xs">
                <div className="flex justify-between gap-4">
                  <dt className="font-mono font-bold uppercase text-dim">USB Plug</dt>
                  <dd className="text-right font-medium text-ink">{board.usbConnector}</dd>
                </div>
                <div className="flex justify-between gap-4">
                  <dt className="font-mono font-bold uppercase text-dim">Status Indicator</dt>
                  <dd className="text-right font-medium text-ink">{board.statusIndicator}</dd>
                </div>
                <div className="flex justify-between gap-4">
                  <dt className="font-mono font-bold uppercase text-dim">Target PC Port</dt>
                  <dd className="text-right font-medium text-ink">{board.pcPortNote}</dd>
                </div>
              </dl>
            </div>
            <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t-2 border-hairline pt-3">
              <a
                href={amazonBuyUrl(board)}
                target="_blank"
                rel="sponsored noopener noreferrer"
                className="inline-flex items-center gap-1.5 font-mono text-xs font-bold text-accent hover:underline"
              >
                <ShoppingCart className="h-3.5 w-3.5" />
                Buy on Amazon ↗
              </a>
              <a
                href="#flash"
                onClick={() => onPickBoardForFlash(board.id)}
                className="font-mono text-xs font-bold text-accent hover:underline"
              >
                Flash {board.shortName} →
              </a>
            </div>
          </article>
        ))}
      </div>

      <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel mt-10 min-w-0 p-5">
        <div className="flex items-center gap-2">
          <Cpu className="h-4 w-4 text-bad" />
          <h3 className="text-base font-bold text-ink">Boards and chips that will NOT work</h3>
        </div>
        <p className="mt-1 max-w-[65ch] text-sm text-muted">
          Other Espressif chips share similar names on store listings, but lack one of the two hardware&nbsp;blocks:
        </p>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[540px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b-2 border-ink-border font-mono text-xs uppercase text-muted">
                <th className="py-2 pr-4">Chip</th>
                <th className="py-2 pr-4">BLE</th>
                <th className="py-2 pr-4">Native USB-OTG</th>
                <th className="py-2">Why</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              <tr className="bg-ok/10">
                <td className="py-2.5 pr-4 font-mono font-bold text-ok">ESP32-S3</td>
                <td className="py-2.5 pr-4 text-ok">
                  <Check className="inline h-4 w-4" aria-label="Yes" />
                </td>
                <td className="py-2.5 pr-4 text-ok">
                  <Check className="inline h-4 w-4" aria-label="Yes" />
                </td>
                <td className="py-2.5 font-medium text-ink">Supported. Runs both BLE and USB HID mouse + keyboard.</td>
              </tr>
              {INCOMPATIBLE_CHIPS.map((row) => (
                <tr key={row.chip}>
                  <td className="py-2.5 pr-4 font-mono font-semibold text-ink">{row.chip}</td>
                  <td className="py-2.5 pr-4">
                    {row.hasBle ? (
                      <Check className="inline h-4 w-4 text-ok" aria-label="Yes" />
                    ) : (
                      <X className="inline h-4 w-4 text-bad" aria-label="No" />
                    )}
                  </td>
                  <td className="py-2.5 pr-4">
                    {row.hasUsbOtg ? (
                      <Check className="inline h-4 w-4 text-ok" aria-label="Yes" />
                    ) : (
                      <X className="inline h-4 w-4 text-bad" aria-label="No" />
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
