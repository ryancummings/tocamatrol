import { Bluetooth, RotateCcw, ShieldCheck } from "lucide-react";
import { STATUS_GUIDE } from "../data/boards";

export function PairingSection() {
  return (
    <section id="pair" className="scroll-mt-20 border-t-2 border-ink-border py-14">
      <h2 className="font-display text-2xl tracking-tight text-ink sm:text-3xl">
        Pairing your iPhone or iPad to the dongle
      </h2>
      <p className="mt-2 max-w-[65ch] text-sm leading-relaxed text-muted">
        For security, the dongle accepts input only from bonded devices over an encrypted BLE link and
        exposes only standard USB HID mouse and keyboard interfaces to your&nbsp;computer.
      </p>

      <div className="mt-8 grid grid-cols-1 gap-5 md:grid-cols-3">
        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 p-5">
          <div className="flex items-center gap-2.5 font-mono text-xs font-bold uppercase text-ink">
            <span className="flex h-6 w-6 items-center justify-center rounded-md border-2 border-pop-ink bg-yellow text-pop-ink">
              1
            </span>
            Plug in &amp; open window
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Plug the flashed dongle into your PC, Mac, or Linux machine (on DevKitC-1, use the port labeled{" "}
            <strong className="text-ink">USB</strong>). The <strong className="text-ink">60-second pairing window</strong>{" "}
            opens automatically on power-up, or whenever you press the <strong className="text-ink">BOOT</strong>{" "}
            button briefly.
          </p>
        </div>

        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 p-5">
          <div className="flex items-center gap-2.5 font-mono text-xs font-bold uppercase text-ink">
            <span className="flex h-6 w-6 items-center justify-center rounded-md border-2 border-pop-ink bg-yellow text-pop-ink">
              2
            </span>
            Pair in the app
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Open Tocamatrol on your iPhone or iPad, tap the <strong className="text-ink">Dongle</strong> button
            at the top-left, find <code className="font-mono font-bold text-accent-label">Tocamatrol XXXX</code> under{" "}
            <em>New dongles nearby</em>, tap <strong className="text-ink">Pair</strong>, and accept the iOS{" "}
            <em>Bluetooth Pairing Request</em>.
          </p>
        </div>

        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 p-5">
          <div className="flex items-center gap-2.5 font-mono text-xs font-bold uppercase text-ink">
            <span className="flex h-6 w-6 items-center justify-center rounded-md border-2 border-pop-ink bg-yellow text-pop-ink">
              3
            </span>
            Use &amp; reconnect
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Once connected (steady green), tap any macro or switch to Trackpad mode. Bonded devices
            reconnect automatically whenever in range—up to <strong className="text-ink">3 devices</strong>{" "}
            (such as an iPhone and iPad together) can share one dongle.
          </p>
        </div>
      </div>

      <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel mt-8 min-w-0 p-5">
        <div className="flex items-center gap-2">
          <Bluetooth className="h-4 w-4 text-accent" />
          <h3 className="text-base font-bold text-ink">Dongle status screen &amp; LED meanings</h3>
        </div>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[560px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b-2 border-ink-border font-mono text-xs uppercase text-muted">
                <th className="py-2 pr-4">State</th>
                <th className="py-2 pr-4">T-Dongle-S3 LCD</th>
                <th className="py-2 pr-4">LED Pattern</th>
                <th className="py-2">Meaning</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline">
              {STATUS_GUIDE.map((row) => (
                <tr key={row.state}>
                  <td className="py-2.5 pr-4 font-bold text-ink">{row.state}</td>
                  <td className="py-2.5 pr-4 font-mono text-xs font-bold text-accent-label">{row.screenText}</td>
                  <td className="py-2.5 pr-4 text-xs text-muted">{row.ledPattern}</td>
                  <td className="py-2.5 text-muted">{row.meaning}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-5 md:grid-cols-2">
        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 p-5">
          <div className="flex items-center gap-2 text-ink">
            <RotateCcw className="h-4 w-4 text-accent-label" />
            <h3 className="font-bold">Resetting or re-pairing a dongle</h3>
          </div>
          <p className="mt-2 max-w-[60ch] text-sm text-muted">
            Hold the dongle&apos;s <strong className="text-ink">BOOT</strong> button for{" "}
            <strong className="text-ink">5 seconds</strong> to erase all stored BLE bonds and open a fresh
            pairing window. On your iPhone or iPad, also open{" "}
            <em>Settings → Bluetooth → ⓘ → Forget This Device</em> before pairing again.
          </p>
        </div>

        <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel min-w-0 p-5">
          <div className="flex items-center gap-2 text-ink">
            <ShieldCheck className="h-4 w-4 text-ok" />
            <h3 className="font-bold">Renaming &amp; using multiple dongles</h3>
          </div>
          <p className="mt-2 max-w-[60ch] text-sm text-muted">
            Once connected, tap <strong className="text-ink">Dongle → Rename…</strong> in the app to give
            each dongle a friendly name (up to 20 characters). The name persists across power cycles and
            appears on the T-Dongle-S3 LCD so you can tell desks apart.
          </p>
        </div>
      </div>
    </section>
  );
}
