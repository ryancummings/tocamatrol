export function PrivacyPage() {
  return (
    <div className="min-h-screen bg-ground text-ink">
      <header className="border-b border-hairline bg-ground">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-4 sm:px-6">
          <a href="../" className="font-mono text-sm font-semibold text-ink hover:text-amber-label">
            ← TOCAMATROL
          </a>
          <span className="font-mono text-xs text-dim">Privacy Policy</span>
        </div>
      </header>

      <main className="mx-auto max-w-3xl space-y-6 px-4 py-12 text-sm leading-relaxed text-muted sm:px-6">
        <div>
          <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">// Privacy</p>
          <h1 className="mt-2 text-3xl font-semibold text-ink">Tocamatrol Privacy Policy</h1>
          <p className="mt-1 font-mono text-xs text-dim">Effective November 25, 2026</p>
        </div>

        <section className="space-y-2 rounded-xl border border-hairline bg-surface p-5">
          <h2 className="text-base font-semibold text-ink">No data collected</h2>
          <p>
            Tocamatrol does not collect, transmit, store, or share personal information, usage telemetry,
            crash analytics, or advertising identifiers. There are no accounts, no cloud sync, and no
            third-party tracking SDKs.
          </p>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-ink">Bluetooth Low Energy</h2>
          <p>
            The iOS and iPadOS app requests Bluetooth permission solely to discover, bond with, and send
            keyboard and pointer packets directly to your ESP32-S3 USB dongle over local Bluetooth Low
            Energy.
          </p>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-ink">On-device macro storage &amp; Face ID lock</h2>
          <p>
            Your macros, custom pages, and settings are stored only on your device using iOS{" "}
            <code className="font-mono text-amber-label">NSFileProtectionComplete</code> encryption while your
            device is locked. If you enable Face ID / Touch ID / Passcode lock in Settings, authentication is
            handled entirely by iOS LocalAuthentication and never leaves your device. Exported JSON macro
            files go only where you explicitly save or share them.
          </p>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-ink">Web Flasher</h2>
          <p>
            The browser web flasher runs completely locally in your browser using the Web Serial API and
            serves static firmware files without cookies or analytics.
          </p>
        </section>

        <section className="space-y-2">
          <h2 className="text-base font-semibold text-ink">Contact</h2>
          <p>
            For questions or support, open an issue on{" "}
            <a
              href="https://github.com/ryancummings/tocamatrol/issues"
              className="text-amber-label underline-offset-4 hover:underline"
            >
              github.com/ryancummings/tocamatrol
            </a>
            .
          </p>
        </section>
      </main>
    </div>
  );
}
