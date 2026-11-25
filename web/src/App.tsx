import { useState } from "react";
import { ArrowRight, Bluetooth, Code2, Cpu, Keyboard, MousePointer, Smartphone } from "lucide-react";
import { BOARDS } from "./data/boards";
import { FlasherSection } from "./components/FlasherSection";
import { HardwareSection } from "./components/HardwareSection";
import { PairingSection } from "./components/PairingSection";

export function App() {
  const [selectedBoardId, setSelectedBoardId] = useState(BOARDS[0].id);

  return (
    <div className="min-h-screen bg-ground text-ink">
      <header className="sticky top-0 z-20 border-b border-hairline bg-ground/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 sm:px-6">
          <a href="#" className="flex items-center gap-2.5 font-mono text-sm font-semibold tracking-wide text-ink">
            <span className="grid h-6 w-6 grid-cols-2 gap-0.5 rounded bg-raised p-1">
              <span className="rounded-[1px] bg-amber" />
              <span className="rounded-[1px] bg-[#8eb8e5]" />
              <span className="rounded-[1px] bg-[#b9ddb0]" />
              <span className="rounded-[1px] bg-[#e8d27a]" />
            </span>
            TOCAMATROL
          </a>
          <nav aria-label="Primary" className="flex items-center gap-4 text-xs font-medium text-muted sm:gap-6 sm:text-sm">
            <a href="#hardware" className="hover:text-amber-label">
              Hardware
            </a>
            <a href="#flash" className="hover:text-amber-label">
              Web Flasher
            </a>
            <a href="#pair" className="hover:text-amber-label">
              Pair &amp; Connect
            </a>
            <a href="privacy/" className="hover:text-amber-label">
              Privacy
            </a>
            <a
              href="https://github.com/ryancummings/tocamatrol"
              className="hidden items-center gap-1 rounded border border-hairline bg-surface px-2.5 py-1 font-mono text-xs text-ink hover:border-strong sm:inline-flex"
            >
              <Code2 className="h-3.5 w-3.5 text-amber" />
              GitHub
            </a>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 sm:px-6">
        <section className="py-14 sm:py-20">
          <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">
            // Open Source · MIT · Free on iOS &amp; iPadOS
          </p>
          <h1 className="mt-3 max-w-3xl text-3xl font-semibold tracking-tight text-ink sm:text-5xl">
            Turn your iPhone or iPad into a macro pad and Magic Trackpad—with zero PC software.
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-muted">
            Tocamatrol sends customizable macros and two-finger trackpad gestures over encrypted Bluetooth LE
            to an inexpensive <strong className="text-ink">ESP32-S3 USB dongle</strong>. The dongle acts as a
            standard USB mouse and keyboard, so Windows, macOS, and Linux computers work immediately without
            drivers or companion apps.
          </p>

          <div className="mt-7 flex flex-wrap gap-3">
            <a
              href="#flash"
              className="inline-flex items-center gap-2 rounded-md border border-amber bg-amber px-4 py-2.5 text-sm font-semibold text-ground hover:brightness-110"
            >
              Flash ESP32-S3 Dongle
              <ArrowRight className="h-4 w-4" />
            </a>
            <a
              href="#hardware"
              className="inline-flex items-center gap-2 rounded-md border border-hairline bg-surface px-4 py-2.5 text-sm font-semibold text-ink hover:border-strong"
            >
              Compatible USB Hardware
            </a>
            <a
              href="https://github.com/ryancummings/tocamatrol"
              className="inline-flex items-center gap-2 rounded-md border border-hairline bg-surface px-4 py-2.5 text-sm font-semibold text-muted hover:border-strong hover:text-ink"
            >
              Source on GitHub
            </a>
          </div>

          <div className="mt-10 grid gap-3 rounded-xl border border-hairline bg-surface p-5 sm:grid-cols-3">
            <div className="flex items-start gap-3">
              <Smartphone className="mt-0.5 h-5 w-5 shrink-0 text-amber" />
              <div>
                <p className="font-semibold text-ink">1. iPhone &amp; iPad App</p>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  Arrange, resize, and scale macro buttons across custom grids, or switch to the full-screen
                  2D trackpad.
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Bluetooth className="mt-0.5 h-5 w-5 shrink-0 text-amber" />
              <div>
                <p className="font-semibold text-ink">2. Bonded BLE Link</p>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  15 ms send ticks with LE Secure Connections bonding. Up to 3 paired devices can drive one
                  dongle.
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Cpu className="mt-0.5 h-5 w-5 shrink-0 text-amber" />
              <div>
                <p className="font-semibold text-ink">3. ESP32-S3 USB HID</p>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  Exposes only standard USB mouse (with horizontal &amp; vertical scroll) and keyboard
                  interfaces.
                </p>
              </div>
            </div>
          </div>

          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <div className="flex items-start gap-3 rounded-xl border border-hairline bg-well p-4">
              <Keyboard className="mt-0.5 h-5 w-5 shrink-0 text-amber-label" />
              <div>
                <h2 className="text-sm font-semibold text-ink">Resizable Macro Grids</h2>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  Configure per-page grid rows and columns, drag buttons to rearrange or swap, resize any span
                  (1×1, 2×1, 3×1, 2×2, or custom), customize colors/typefaces/captions, and import/export JSON
                  libraries.
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3 rounded-xl border border-hairline bg-well p-4">
              <MousePointer className="mt-0.5 h-5 w-5 shrink-0 text-amber-label" />
              <div>
                <h2 className="text-sm font-semibold text-ink">Magic Trackpad Mode</h2>
                <p className="mt-1 text-xs leading-relaxed text-muted">
                  Millimetre-calibrated pointer acceleration, tap-to-click, tap-and-drag, two-finger vertical
                  &amp; horizontal scroll with smooth coasting, Natural/Classic scroll toggle, right-click,
                  middle-click, and palm rejection.
                </p>
              </div>
            </div>
          </div>
        </section>

        <HardwareSection onPickBoardForFlash={setSelectedBoardId} />
        <FlasherSection selectedBoardId={selectedBoardId} onSelectBoard={setSelectedBoardId} />
        <PairingSection />

        <section id="support" className="border-t border-hairline py-12">
          <p className="font-mono text-xs uppercase tracking-[0.16em] text-amber">// Support &amp; Source</p>
          <h2 className="mt-1 text-xl font-semibold text-ink">Questions, bug reports, and contributions</h2>
          <p className="mt-2 max-w-2xl text-sm text-muted">
            Tocamatrol is open-source under the MIT license. Report hardware or app issues on{" "}
            <a
              href="https://github.com/ryancummings/tocamatrol/issues"
              className="text-amber-label underline-offset-4 hover:underline"
            >
              GitHub Issues
            </a>
            , or inspect the BLE protocol and firmware sources in the repository.
          </p>
        </section>
      </main>

      <footer className="border-t border-hairline py-8 text-xs text-dim">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 sm:px-6">
          <span className="font-mono">Tocamatrol · MIT License</span>
          <div className="flex items-center gap-5">
            <a href="privacy/" className="hover:text-ink">
              Privacy Policy
            </a>
            <a href="https://github.com/ryancummings/tocamatrol" className="hover:text-ink">
              GitHub
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
