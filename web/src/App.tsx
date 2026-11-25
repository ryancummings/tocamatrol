import { useState } from "react";
import { ArrowRight, Bluetooth, Code2, Cpu, Keyboard, MousePointer, Smartphone } from "lucide-react";
import { BOARDS } from "./data/boards";
import { FlasherSection } from "./components/FlasherSection";
import { HardwareSection } from "./components/HardwareSection";
import { PairingSection } from "./components/PairingSection";

interface DemoKey {
  id: string;
  label: string;
  caption: string;
  readout: string;
  bgClass: string;
  textClass: string;
  wide?: boolean;
}

const DEMO_KEYS: DemoKey[] = [
  {
    id: "copy",
    label: "Copy",
    caption: "Ctrl+C",
    readout: "Copied selection (Ctrl+C -> USB HID)",
    bgClass: "bg-[#1957d6]",
    textClass: "text-white",
  },
  {
    id: "paste",
    label: "Paste",
    caption: "Ctrl+V",
    readout: "Pasted clipboard (Ctrl+V -> USB HID)",
    bgClass: "bg-[#45e3f7]",
    textClass: "text-[#151311]",
  },
  {
    id: "build",
    label: "Save & Build",
    caption: "Ctrl+S, Shift+B · 0.8s",
    readout: "Saved & launched build macro (2× speed)",
    bgClass: "bg-[#4fe36e]",
    textClass: "text-[#151311]",
    wide: true,
  },
  {
    id: "terminal",
    label: "Open Terminal",
    caption: "Win+R -> git status",
    readout: "Opened terminal & typed git status",
    bgClass: "bg-[#ff9e3d]",
    textClass: "text-[#151311]",
    wide: true,
  },
  {
    id: "shot",
    label: "Snap",
    caption: "Win+Shift+S",
    readout: "Captured screen snip over BLE",
    bgClass: "bg-[#b81d66]",
    textClass: "text-white",
  },
  {
    id: "comment",
    label: "Comment",
    caption: "Ctrl+/",
    readout: "Toggled line comment (Ctrl+/)",
    bgClass: "bg-[#ffd21f]",
    textClass: "text-[#151311]",
  },
];

export function App() {
  const [selectedBoardId, setSelectedBoardId] = useState(BOARDS[0].id);
  const [activeKeyId, setActiveKeyId] = useState<string>(DEMO_KEYS[0].id);
  const activeKey = DEMO_KEYS.find((k) => k.id === activeKeyId) ?? DEMO_KEYS[0];

  return (
    <div className="min-h-screen bg-ground text-ink comic-halftone">
      <header className="sticky top-0 z-20 border-b-2 border-ink-border bg-surface/95 backdrop-blur">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-4 gap-y-2 px-4 py-3 sm:px-6">
          <a href="#" className="flex shrink-0 items-center gap-2.5 font-display text-base tracking-tight text-ink">
            <span className="grid h-7 w-7 grid-cols-2 gap-0.5 rounded-md border-2 border-pop-ink bg-pop-ink p-0.5 shadow-[2px_2px_0_0_var(--color-ink-shadow)]">
              <span className="rounded-[2px] bg-[#e63229]" />
              <span className="rounded-[2px] bg-[#45e3f7]" />
              <span className="rounded-[2px] bg-[#4fe36e]" />
              <span className="rounded-[2px] bg-[#1b64f2]" />
            </span>
            TOCAMATROL
          </a>
          <nav
            aria-label="Primary"
            className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs font-bold text-muted sm:gap-x-6 sm:text-sm"
          >
            <a href="#hardware" className="whitespace-nowrap transition hover:text-accent">
              Hardware
            </a>
            <a href="#flash" className="whitespace-nowrap transition hover:text-accent">
              Flasher
            </a>
            <a href="#pair" className="whitespace-nowrap transition hover:text-accent">
              Pairing
            </a>
            <a href="privacy/" className="whitespace-nowrap transition hover:text-accent">
              Privacy
            </a>
            <a
              href="https://github.com/ryancummings/tocamatrol"
              className="comic-btn hidden items-center gap-1.5 rounded-lg bg-yellow px-3 py-1.5 font-mono text-xs font-bold text-pop-ink sm:inline-flex"
            >
              <Code2 className="h-3.5 w-3.5" />
              GitHub
            </a>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 sm:px-6">
        <section className="py-10 sm:py-16">
          <div className="grid grid-cols-1 items-center gap-8 lg:grid-cols-12 lg:gap-10">
            <div className="min-w-0 lg:col-span-7">
              <h1 className="font-display text-3xl leading-[1.08] tracking-[-0.02em] text-ink sm:text-5xl">
                Turn your iPhone or iPad into a macro pad and Magic Trackpad—with zero PC software.
              </h1>
              <p className="mt-5 max-w-[65ch] text-base leading-relaxed text-muted sm:text-lg">
                Tocamatrol sends customizable macros and two-finger trackpad gestures over encrypted Bluetooth LE
                to an inexpensive <strong className="text-ink">ESP32-S3 USB dongle</strong>. The dongle acts as a
                standard USB mouse and keyboard, so Windows, macOS, and Linux work without drivers or&nbsp;apps.
              </p>

              <div className="mt-7 flex flex-wrap gap-3">
                <a
                  href="#flash"
                  data-impeccable-ignore="hard-offset-shadow"
                  className="comic-btn inline-flex items-center gap-2 rounded-xl bg-yellow px-5 py-3 text-sm font-bold text-pop-ink"
                >
                  Flash ESP32-S3 Dongle
                  <ArrowRight className="h-4 w-4" />
                </a>
                <a
                  href="#hardware"
                  data-impeccable-ignore="hard-offset-shadow"
                  className="comic-btn-secondary inline-flex items-center gap-2 rounded-xl bg-surface px-5 py-3 text-sm font-bold text-ink"
                >
                  Compatible USB Hardware
                </a>
                <a
                  href="https://github.com/ryancummings/tocamatrol"
                  data-impeccable-ignore="hard-offset-shadow"
                  className="comic-btn-secondary inline-flex items-center gap-2 rounded-xl bg-well px-5 py-3 text-sm font-bold text-ink"
                >
                  Source on GitHub
                </a>
              </div>

              <div className="mt-6 flex flex-wrap items-center gap-2 text-xs font-bold">
                <span className="rounded-md border-2 border-ink-border bg-surface px-2.5 py-1 text-ink">
                  Open Source · MIT
                </span>
                <span className="rounded-md border-2 border-ink-border bg-surface px-2.5 py-1 text-ink">
                  iOS &amp; iPadOS 17+
                </span>
                <span className="rounded-md border-2 border-ink-border bg-surface px-2.5 py-1 text-ink">
                  Pure USB HID Mouse + Keyboard
                </span>
              </div>
            </div>

            <div className="min-w-0 lg:col-span-5">
              <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel overflow-hidden p-4 sm:p-5">
                <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                  <span className="inline-flex items-center gap-2 rounded-lg border-2 border-ink-border bg-well px-2.5 py-1 font-mono text-xs font-bold text-ink">
                    <span className="h-2.5 w-2.5 rounded-full border border-pop-ink bg-ok" />
                    DONGLE READY
                  </span>
                  <span className="font-mono text-xs font-bold text-dim">Tap a key preview</span>
                </div>

                <div className="grid grid-cols-2 gap-2.5">
                  {DEMO_KEYS.map((item) => {
                    const selected = item.id === activeKeyId;
                    return (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => setActiveKeyId(item.id)}
                        className={`min-w-0 rounded-xl border-2 border-pop-ink px-3 py-3 text-left transition-transform ${
                          item.wide ? "col-span-2" : ""
                        } ${item.bgClass} ${item.textClass} ${
                          selected
                            ? "translate-x-[2px] translate-y-[2px] ring-3 ring-accent shadow-none"
                            : "shadow-[3px_3px_0_0_var(--color-ink-shadow)] hover:-translate-x-0.5 hover:-translate-y-0.5"
                        }`}
                      >
                        <div className="flex flex-wrap items-center justify-between gap-x-2 gap-y-0.5">
                          <span className="text-sm font-bold">{item.label}</span>
                          <span className="font-mono text-[11px] font-semibold opacity-90">{item.caption}</span>
                        </div>
                      </button>
                    );
                  })}
                </div>

                <div className="-mx-4 -mb-4 mt-4 border-t-2 border-ink-border bg-well px-4 py-3 sm:-mx-5 sm:-mb-5 sm:px-5">
                  <span className="inline-block rounded border border-pop-ink bg-yellow px-2 py-0.5 font-sans text-[11px] font-black tracking-wider text-pop-ink uppercase">
                    Last Sent
                  </span>
                  <p className="mt-1.5 font-mono text-xs font-bold text-accent-label">{activeKey.readout}</p>
                </div>
              </div>
            </div>
          </div>

          <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel mt-10 p-5 sm:p-6">
            <ol className="grid grid-cols-1 gap-6 md:grid-cols-3">
              <li className="flex items-start gap-3.5">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border-2 border-pop-ink bg-[#d92b21] text-white shadow-[2px_2px_0_0_var(--color-ink-shadow)]">
                  <Smartphone className="h-5 w-5" />
                </span>
                <div>
                  <p className="font-bold text-ink">1. iPhone &amp; iPad App</p>
                  <p className="mt-1 max-w-[42ch] text-sm leading-relaxed text-muted">
                    Arrange, resize, and color macro buttons across custom grids, or switch to the full-screen
                    2D trackpad.
                  </p>
                </div>
              </li>
              <li className="flex items-start gap-3.5">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border-2 border-pop-ink bg-[#1957d6] text-white shadow-[2px_2px_0_0_var(--color-ink-shadow)]">
                  <Bluetooth className="h-5 w-5" />
                </span>
                <div>
                  <p className="font-bold text-ink">2. Bonded BLE Link</p>
                  <p className="mt-1 max-w-[42ch] text-sm leading-relaxed text-muted">
                    15 ms send ticks with LE Secure Connections bonding. Up to 3 paired devices share one&nbsp;dongle.
                  </p>
                </div>
              </li>
              <li className="flex items-start gap-3.5">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border-2 border-pop-ink bg-[#4fe36e] text-[#151311] shadow-[2px_2px_0_0_var(--color-ink-shadow)]">
                  <Cpu className="h-5 w-5" />
                </span>
                <div>
                  <p className="font-bold text-ink">3. ESP32-S3 USB HID</p>
                  <p className="mt-1 max-w-[42ch] text-sm leading-relaxed text-muted">
                    Exposes only standard USB mouse (horizontal &amp; vertical scroll) and keyboard&nbsp;interfaces.
                  </p>
                </div>
              </li>
            </ol>
          </div>

          <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-12">
            <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel flex items-start gap-3.5 bg-well p-5 md:col-span-7">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border-2 border-pop-ink bg-yellow text-pop-ink">
                <Keyboard className="h-4.5 w-4.5" />
              </span>
              <div>
                <h2 className="text-base font-bold text-ink">Resizable Macro Grids</h2>
                <p className="mt-1 max-w-[58ch] text-sm leading-relaxed text-muted">
                  Configure per-page grid rows and columns, drag buttons to rearrange or swap, resize any span
                  (1×1, 2×1, 3×1, 2×2, or custom), pick colors and typefaces, and import/export JSON&nbsp;libraries.
                </p>
              </div>
            </div>
            <div data-impeccable-ignore="hard-offset-shadow" className="comic-panel flex items-start gap-3.5 bg-well p-5 md:col-span-5">
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border-2 border-pop-ink bg-cyan text-[#151311]">
                <MousePointer className="h-4.5 w-4.5" />
              </span>
              <div>
                <h2 className="text-base font-bold text-ink">Magic Trackpad Mode</h2>
                <p className="mt-1 max-w-[48ch] text-sm leading-relaxed text-muted">
                  Millimetre-calibrated pointer curves, tap-to-click, tap-and-drag, two-finger inertial
                  scrolling, Natural/Classic toggle, middle-click, and palm&nbsp;rejection.
                </p>
              </div>
            </div>
          </div>
        </section>

        <HardwareSection onPickBoardForFlash={setSelectedBoardId} />
        <FlasherSection selectedBoardId={selectedBoardId} onSelectBoard={setSelectedBoardId} />
        <PairingSection />

        <section id="support" className="border-t-2 border-ink-border py-12">
          <h2 className="font-display text-2xl tracking-tight text-ink">Questions, bug reports, and contributions</h2>
          <p className="mt-2 max-w-[65ch] text-sm leading-relaxed text-muted">
            Tocamatrol is open-source under the MIT license. Report hardware or app issues on{" "}
            <a
              href="https://github.com/ryancummings/tocamatrol/issues"
              className="font-bold text-accent underline"
            >
              GitHub Issues
            </a>
            , or inspect the BLE protocol and firmware sources in the&nbsp;repository.
          </p>
        </section>
      </main>

      <footer className="border-t-2 border-ink-border bg-surface py-8 text-xs font-semibold text-dim">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 sm:px-6">
          <span className="font-mono">Tocamatrol · MIT License</span>
          <div className="flex items-center gap-5">
            <a href="privacy/" className="transition hover:text-ink">
              Privacy Policy
            </a>
            <a href="https://github.com/ryancummings/tocamatrol" className="transition hover:text-ink">
              GitHub
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
