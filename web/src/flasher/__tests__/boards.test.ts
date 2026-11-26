import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { AMAZON_ASSOCIATE_TAG, BOARDS, INCOMPATIBLE_CHIPS, amazonBuyUrl } from "../../data/boards";

describe("boards.json hardware catalog", () => {
  const repoRoot = resolve(process.cwd(), "..");
  const pioIni = readFileSync(resolve(repoRoot, "dongle/platformio.ini"), "utf8");

  it("defines unique ESP32-S3 boards matching dongle/platformio.ini environments", () => {
    expect(BOARDS.length).toBeGreaterThanOrEqual(4);

    const ids = new Set<string>();
    const filenames = new Set<string>();

    for (const board of BOARDS) {
      expect(board.chip).toBe("ESP32-S3");
      expect(ids.has(board.id)).toBe(false);
      expect(filenames.has(board.flashFilename)).toBe(false);
      ids.add(board.id);
      filenames.add(board.flashFilename);

      expect(pioIni).toContain(`[env:${board.pioEnv}]`);
    }

    const defaultEnvsMatch = pioIni.match(/^default_envs\s*=\s*(.+)$/m);
    expect(defaultEnvsMatch).not.toBeNull();
    const defaultEnvs = defaultEnvsMatch![1].split(",").map((s) => s.trim());

    for (const board of BOARDS) {
      expect(defaultEnvs).toContain(board.pioEnv);
    }
  });

  it("gives every board a tagged Amazon buy link", () => {
    const asins = new Set<string>();
    for (const board of BOARDS) {
      expect(board.amazonAsin).toMatch(/^B0[A-Z0-9]{8}$/);
      expect(asins.has(board.amazonAsin)).toBe(false);
      asins.add(board.amazonAsin);
      expect(amazonBuyUrl(board)).toBe(`https://www.amazon.com/dp/${board.amazonAsin}?tag=${AMAZON_ASSOCIATE_TAG}`);
    }
  });

  it("documents common incompatible Espressif chips", () => {
    const chips = INCOMPATIBLE_CHIPS.map((c) => c.chip);
    expect(chips).toContain("ESP32");
    expect(chips).toContain("ESP32-S2");
    expect(chips).toContain("ESP32-C3");
    expect(chips).toContain("ESP32-C6");
  });
});
