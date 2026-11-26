// Render promo.html frame by frame in headless Chrome and encode the how-it-works video
// into web/public/media/ (MP4 H.264, WebM VP9, JPEG poster). Needs Google Chrome and ffmpeg.
//   cd tools/promo_video && npm install && npm run render
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright-core";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "../../web/public/media");
const NAME = "tocamatrol-how-it-works";
const FPS = 30, SECONDS = 14, POSTER_T = 5.5;
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const frames = mkdtempSync(join(tmpdir(), "toca-promo-"));
const browser = await chromium.launch({ executablePath: CHROME });
try {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  page.on("pageerror", (e) => { throw e; });
  await page.goto(pathToFileURL(join(HERE, "promo.html")).href + "?capture");
  await page.evaluate(() => window.ready);
  for (let i = 0; i < FPS * SECONDS; i++) {
    await page.evaluate((t) => window.render(t), i / FPS);
    await page.screenshot({ path: join(frames, `f${String(i).padStart(4, "0")}.png`) });
  }
  await page.evaluate((t) => window.render(t), POSTER_T);
  await page.screenshot({ path: join(frames, "poster.png") });
} finally {
  await browser.close();
}

const ff = (...args) => execFileSync("ffmpeg", ["-y", "-loglevel", "error", ...args], { stdio: "inherit" });
const input = ["-framerate", String(FPS), "-i", join(frames, "f%04d.png")];
ff(...input, "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", join(OUT, `${NAME}.mp4`));
ff(...input, "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "34", "-row-mt", "1", "-pix_fmt", "yuv420p", "-an", join(OUT, `${NAME}.webm`));
ff("-i", join(frames, "poster.png"), "-q:v", "3", join(OUT, `${NAME}-poster.jpg`));
rmSync(frames, { recursive: true });
console.log(`Wrote ${NAME}.mp4, .webm and -poster.jpg to ${OUT}`);
