export function PrivacyPage() {
  return (
    <div className="min-h-screen bg-ground text-ink comic-halftone">
      <header className="border-b-2 border-ink-border bg-surface">
        <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-4 sm:px-6">
          <a href="../" className="font-display text-sm tracking-wide text-ink hover:text-accent">
            ← TOCAMATROL
          </a>
          <span className="rounded-md border-2 border-pop-ink bg-yellow px-2.5 py-0.5 font-mono text-xs font-bold text-pop-ink">
            Privacy Policy
          </span>
        </div>
      </header>

      <main className="mx-auto max-w-3xl space-y-6 px-4 py-12 text-sm leading-relaxed text-muted sm:px-6">
        <div>
          <h1 className="font-display text-3xl text-ink">Tocamatrol Privacy Policy</h1>
          <p className="mt-1 font-mono text-xs font-semibold text-dim">Effective November 25, 2026</p>
        </div>

        <section data-impeccable-ignore="hard-offset-shadow" className="comic-panel space-y-2 p-5">
          <h2 className="text-base font-bold text-ink">No data collected</h2>
          <p className="max-w-[65ch]">
            Tocamatrol does not collect, transmit, store, or share personal information, usage telemetry,
            crash analytics, or advertising identifiers. There are no accounts, no cloud sync, and no
            third-party tracking SDKs.
          </p>
        </section>

        <section data-impeccable-ignore="hard-offset-shadow" className="comic-panel space-y-2 p-5">
          <h2 className="text-base font-bold text-ink">Bluetooth Low Energy</h2>
          <p className="max-w-[65ch]">
            The iOS and iPadOS app requests Bluetooth permission solely to discover, bond with, and send
            keyboard and pointer packets directly to your ESP32-S3 USB dongle over local Bluetooth Low
            Energy.
          </p>
        </section>

        <section data-impeccable-ignore="hard-offset-shadow" className="comic-panel space-y-2 p-5">
          <h2 className="text-base font-bold text-ink">On-device macro storage &amp; Face ID lock</h2>
          <p className="max-w-[65ch]">
            Your macros, custom pages, and settings are stored only on your device using iOS{" "}
            <code className="font-mono font-bold text-accent-label">NSFileProtectionComplete</code> encryption while your
            device is locked. If you enable Face ID / Touch ID / Passcode lock in Settings, authentication is
            handled entirely by iOS LocalAuthentication and never leaves your device. Exported JSON macro
            files go only where you explicitly save or share them.
          </p>
        </section>

        <section data-impeccable-ignore="hard-offset-shadow" className="comic-panel space-y-2 p-5">
          <h2 className="text-base font-bold text-ink">Web Flasher</h2>
          <p className="max-w-[65ch]">
            The browser web flasher runs completely locally in your browser using the Web Serial API and
            serves static firmware files without cookies or analytics.
          </p>
        </section>

        <section data-impeccable-ignore="hard-offset-shadow" className="comic-panel space-y-2 p-5">
          <h2 className="text-base font-bold text-ink">Contact</h2>
          <p className="max-w-[65ch]">
            For questions or support, open an issue on{" "}
            <a
              href="https://github.com/ryancummings/tocamatrol/issues"
              className="font-bold text-accent underline"
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
