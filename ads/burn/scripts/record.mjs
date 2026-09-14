#!/usr/bin/env node
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const PUBLIC = path.join(ROOT, "public");
const OUT = path.join(ROOT, "out");
const FPS = 30;
const DURATION = 30;
const FRAMES = FPS * DURATION;

const SIZES = [
  { name: "1920x1080", w: 1920, h: 1080 },
  { name: "1080x1920", w: 1080, h: 1920 },
];

const BEATS = [
  { t: 1.6, file: "beat_1_type", expect: "gate" },
  { t: 4.6, file: "beat_2_reveal", expect: "BURN NOTE" },
  { t: 8.0, file: "beat_3_encrypt", expect: "ENCRYPTING" },
  { t: 12.6, file: "beat_4_ready", expect: "77" },
  { t: 17.4, file: "beat_5_open", expect: "gate code" },
  { t: 22.15, file: "beat_6_gone", expect: "app.nosus.foo" },
  { t: 25.1, file: "beat_7_file", expect: "handoff.pdf" },
  { t: 28.6, file: "beat_8_end", expect: "NO SUS" },
];

const FORBIDDEN_SUPERS = [
  "Encrypts in your browser.",
  "The key lives in the link.",
  "One open. Then it's gone.",
  "Notes or one file. No account.",
];

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".woff2": "font/woff2",
  ".png": "image/png",
  ".wav": "audio/wav",
  ".svg": "image/svg+xml",
};

function serve(dir) {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      const url = new URL(req.url, "http://127.0.0.1");
      let rel = decodeURIComponent(url.pathname);
      if (rel === "/") rel = "/index.html";
      const file = path.join(dir, rel);
      if (!file.startsWith(dir) || !existsSync(file) || statSync(file).isDirectory()) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      const ext = path.extname(file);
      res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
      createReadStream(file).pipe(res);
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function ffmpegPipe(outFile, w, h) {
  const args = [
    "-y",
    "-f", "image2pipe",
    "-framerate", String(FPS),
    "-c:v", "mjpeg",
    "-i", "pipe:0",
    "-an",
    "-c:v", "libx264",
    "-pix_fmt", "yuv420p",
    "-crf", "17",
    "-preset", "medium",
    "-movflags", "+faststart",
    "-r", String(FPS),
    "-s", `${w}x${h}`,
    outFile,
  ];
  const ff = spawn("ffmpeg", args, { stdio: ["pipe", "inherit", "inherit"] });
  return ff;
}

async function waitReady(page) {
  await page.waitForFunction(() => window.__burnReady === true, null, { timeout: 20000 });
  await page.evaluate(async () => {
    await document.fonts.ready;
    const img = document.querySelector("img");
    if (img && !img.complete) {
      await new Promise((res) => { img.onload = img.onerror = res; });
    }
  });
  await page.evaluate(() => window.__burnSeek(0));
}

async function grabBeats(page, prefix) {
  const shots = path.join(OUT, "beats");
  mkdirSync(shots, { recursive: true });
  const results = [];
  for (const beat of BEATS) {
    await page.evaluate((t) => window.__burnSeek(t), beat.t);
    const body = await page.locator("body").innerText();
    const png = path.join(shots, `${prefix}_${beat.file}.png`);
    await page.screenshot({ path: png, type: "png" });
    const leaked = FORBIDDEN_SUPERS.filter((s) => body.includes(s));
    const ok = body.includes(beat.expect) && leaked.length === 0;
    results.push({ ...beat, ok, leaked, excerpt: body.replace(/\s+/g, " ").slice(0, 180) });
    if (!ok) {
      console.warn(`BEAT MISS ${prefix} t=${beat.t} expected ${JSON.stringify(beat.expect)} leaked ${JSON.stringify(leaked)} got ${JSON.stringify(results.at(-1).excerpt)}`);
    } else {
      console.log(`beat ok ${prefix} t=${beat.t} ${beat.file}`);
    }
  }
  return results;
}

async function recordSize(browser, origin, size) {
  const page = await browser.newPage({
    viewport: { width: size.w, height: size.h },
    deviceScaleFactor: 1,
  });
  const url = `${origin}/index.html?record=1&w=${size.w}&h=${size.h}`;
  await page.goto(url, { waitUntil: "networkidle" });
  await waitReady(page);
  const beatResults = await grabBeats(page, size.name);

  const outFile = path.join(OUT, `burn_ad_${size.name}.mp4`);
  const ff = ffmpegPipe(outFile, size.w, size.h);
  const failed = [];
  ff.on("error", (err) => failed.push(err));

  for (let i = 0; i < FRAMES; i++) {
    const t = i / FPS;
    await page.evaluate((t) => window.__burnSeek(t), t);
    const buf = await page.screenshot({ type: "jpeg", quality: 92 });
    if (!ff.stdin.write(buf)) {
      await new Promise((res) => ff.stdin.once("drain", res));
    }
    if (i % 90 === 0) console.log(`${size.name} frame ${i}/${FRAMES} t=${t.toFixed(2)}`);
  }
  ff.stdin.end();
  const code = await new Promise((resolve, reject) => {
    ff.on("close", resolve);
    ff.on("error", reject);
  });
  await page.close();
  if (code !== 0) throw new Error(`ffmpeg ${size.name} exited ${code}`);
  console.log("wrote", outFile);
  return { outFile, beatResults };
}

async function main() {
  if (!existsSync(path.join(PUBLIC, "ad.js"))) {
    throw new Error("public/ad.js missing — run npm run build first");
  }
  mkdirSync(OUT, { recursive: true });
  const server = await serve(PUBLIC);
  const { port } = server.address();
  const origin = `http://127.0.0.1:${port}`;
  const browser = await chromium.launch({
    channel: "chrome",
    args: ["--hide-scrollbars", "--font-render-hinting=none"],
  });
  try {
    const reports = [];
    for (const size of SIZES) {
      reports.push(await recordSize(browser, origin, size));
    }
    writeFileSync(path.join(OUT, "beat_report.json"), JSON.stringify(reports, null, 2));
    const misses = reports.flatMap((r) => r.beatResults.filter((b) => !b.ok));
    if (misses.length) {
      console.error("beat text misses", misses);
      process.exitCode = 2;
    }
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
