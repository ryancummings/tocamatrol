import { Bluetooth, RotateCcw, ShieldCheck } from "lucide-react";
import { STATUS_GUIDE } from "../data/boards";

export function PairingSection() {
  return (
    <section id="pair" className="scroll-mt-20 border-t border-hairline py-14">
      <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">// Pair &amp; Connect</p>
      <h2 className="mt-1 text-2xl font-semibold tracking-tight text-ink sm:text-3xl">
        Pairing your iPhone or iPad to the dongle
      </h2>
      <p className="mt-2 max-w-3xl text-sm text-muted">
        For security, the dongle accepts input only from bonded devices over an encrypted BLE link and
        exposes only standard USB HID mouse and keyboard interfaces to your computer.
      </p>

      <div className="mt-8 grid gap-4 md:grid-cols-3">
        <div className="rounded-xl border border-hairline bg-surface p-5">
          <div className="flex items-center gap-2 font-mono text-xs uppercase text-amber-label">
            <span className="flex h-5 w-5 items-center justify-center rounded bg-amber/20">1</span>
            Plug in &amp; open window
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Plug the flashed dongle into your PC, Mac, or Linux machine (on DevKitC-1, use the port labeled{" "}
            <strong className="text-ink">USB</strong>). The <strong className="text-ink">60-second pairing window</strong>{" "}
            opens automatically on power-up, or whenever you press the <strong className="text-ink">BOOT</strong>{" "}
            button briefly.
          </p>
        </div>

        <div className="rounded-xl border border-hairline bg-surface p-5">
          <div className="flex items-center gap-2 font-mono text-xs uppercase text-amber-label">
            <span className="flex h-5 w-5 items-center justify-center rounded bg-amber/20">2</span>
            Pair in the app
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Open Tocamatrol on your iPhone or iPad, tap the <strong className="text-ink">Dongle</strong> button
            at the top-left, find <code className="font-mono text-amber-label">Tocamatrol XXXX</code> under{" "}
            <em>New dongles nearby</em>, tap <strong className="text-ink">Pair</strong>, and accept the iOS{" "}
            <em>Bluetooth Pairing Request</em>.
          </p>
        </div>

        <div className="rounded-xl border border-hairline bg-surface p-5">
          <div className="flex items-center gap-2 font-mono text-xs uppercase text-amber-label">
            <span className="flex h-5 w-5 items-center justify-center rounded bg-amber/20">3</span>
            Use &amp; reconnect
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted">
            Once connected (steady green), tap any macro or switch to Trackpad mode. Bonded devices
            reconnect automatically whenever in range—up to <strong className="text-ink">3 devices</strong>{" "}
            (such as an iPhone and iPad together) can share one dongle.
          </p>
        </div>
      </div>

      <div className="mt-8 rounded-xl border border-hairline bg-surface p-5">
        <div className="flex items-center gap-2">
          <Bluetooth className="h-4 w-4 text-amber" />
          <h3 className="text-base font-semibold text-ink">Dongle status screen &amp; LED meanings</h3>
        </div>
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[560px] border-collapse text-left text-sm">
            <thead>
              <tr className="border-b border-hairline font-mono text-xs uppercase text-dim">
                <th className="py-2 pr-4">State</th>
                <th className="py-2 pr-4">T-Dongle-S3 LCD</th>
                <th className="py-2 pr-4">LED Pattern</th>
                <th className="py-2">Meaning</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-hairline/60">
              {STATUS_GUIDE.map((row) => (
                <tr key={row.state}>
                  <td className="py-2.5 pr-4 font-semibold text-ink">{row.state}</td>
                  <td className="py-2.5 pr-4 font-mono text-xs text-amber-label">{row.screenText}</td>
                  <td className="py-2.5 pr-4 text-xs text-muted">{row.ledPattern}</td>
                  <td className="py-2.5 text-muted">{row.meaning}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <div className="rounded-xl border border-hairline bg-surface p-5">
          <div className="flex items-center gap-2 text-ink">
            <RotateCcw className="h-4 w-4 text-amber" />
            <h3 className="font-semibold">Resetting or re-pairing a dongle</h3>
          </div>
          <p className="mt-2 text-sm text-muted">
            Hold the dongle&apos;s <strong className="text-ink">BOOT</strong> button for{" "}
            <strong className="text-ink">5 seconds</strong> to erase all stored BLE bonds and open a fresh
            pairing window. On your iPhone or iPad, also open{" "}
            <em>Settings → Bluetooth → ⓘ → Forget This Device</em> before pairing again.
          </p>
        </div>

        <div className="rounded-xl border border-hairline bg-surface p-5">
          <div className="flex items-center gap-2 text-ink">
            <ShieldCheck className="h-4 w-4 text-ok" />
            <h3 className="font-semibold">Renaming &amp; using multiple dongles</h3>
          </div>
          <p className="mt-2 text-sm text-muted">
            Once connected, tap <strong className="text-ink">Dongle → Rename…</strong> in the app to give
            each dongle a friendly name (up to 20 characters). The name persists across power cycles and
            appears on the T-Dongle-S3 LCD so you can tell desks apart.
          </p>
        </div>
      </div>
    </section>
  );
}
