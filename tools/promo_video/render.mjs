// Render promo.html frame by frame in headless Chrome and encode it. Needs Google Chrome and ffmpeg.
//   cd tools/promo_video && npm install
//   npm run render        web: the how-it-works video in web/public/media/ (MP4 H.264, WebM VP9, JPEG poster)
//   npm run render:store  App Store creative asset videos in ios/fastlane/creative/ (gitignored):
//                         header_21x9.mp4 (3840x1646) and search_3x2.mp4 (3840x2560), H.264 with a
//                         silent stereo AAC track, 30 fps, 14 s seamless loop
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright-core";

const HERE = dirname(fileURLToPath(import.meta.url));
const FPS = 30, SECONDS = 14, POSTER_T = 5.5;
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const target = process.argv[2] ?? "web";

const ff = (...args) => execFileSync("ffmpeg", ["-y", "-loglevel", "error", ...args], { stdio: "inherit" });

// Capture every frame of one loop (and optionally a poster) into a temp directory.
async function capture({ query, width, height, scale = 1, poster = false }) {
  const frames = mkdtempSync(join(tmpdir(), "toca-promo-"));
  const browser = await chromium.launch({ executablePath: CHROME });
  try {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: scale });
    page.on("pageerror", (e) => { throw e; });
    await page.goto(pathToFileURL(join(HERE, "promo.html")).href + "?capture" + query);
    await page.evaluate(() => window.ready);
    for (let i = 0; i < FPS * SECONDS; i++) {
      await page.evaluate((t) => window.render(t), i / FPS);
      await page.screenshot({ path: join(frames, `f${String(i).padStart(4, "0")}.png`) });
    }
    if (poster) {
      await page.evaluate((t) => window.render(t), POSTER_T);
      await page.screenshot({ path: join(frames, "poster.png") });
    }
  } finally {
    await browser.close();
  }
  return frames;
}

const input = (frames) => ["-framerate", String(FPS), "-i", join(frames, "f%04d.png")];

if (target === "web") {
  const OUT = join(HERE, "../../web/public/media");
  const NAME = "tocamatrol-how-it-works";
  const frames = await capture({ query: "", width: 1920, height: 1080, poster: true });
  ff(...input(frames), "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", join(OUT, `${NAME}.mp4`));
  ff(...input(frames), "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "34", "-row-mt", "1", "-pix_fmt", "yuv420p", "-an", join(OUT, `${NAME}.webm`));
  ff("-i", join(frames, "poster.png"), "-q:v", "3", join(OUT, `${NAME}-poster.jpg`));
  rmSync(frames, { recursive: true });
  console.log(`Wrote ${NAME}.mp4, .webm and -poster.jpg to ${OUT}`);
} else if (target === "store") {
  // The page renders at half size; deviceScaleFactor 2 gives Apple's 3840 px width.
  const OUT = join(HERE, "../../ios/fastlane/creative");
  mkdirSync(OUT, { recursive: true });
  const assets = [
    { name: "header_21x9", format: "header", width: 1920, height: 823, crop: "3840:1646:0:0" },
    { name: "search_3x2", format: "search", width: 1920, height: 1280, crop: "3840:2560:0:0" },
  ];
  for (const a of assets) {
    const frames = await capture({ query: `&format=${a.format}&motion`, width: a.width, height: a.height, scale: 2 });
    const out = join(OUT, `${a.name}.mp4`);
    ff(...input(frames), "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
      "-vf", `crop=${a.crop},format=yuv420p`, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
      "-profile:v", "high", "-level", "5.1", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
      "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", out);
    rmSync(frames, { recursive: true });
    console.log(`Wrote ${out}`);
  }
} else {
  throw new Error(`Unknown target ${target}: use web or store`);
}
