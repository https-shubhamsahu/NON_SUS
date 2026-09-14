#!/usr/bin/env node
import playwright from "../../burn/node_modules/playwright/index.js";

const { chromium } = playwright;
import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const PUBLIC = path.join(ROOT, "public");
const OUT = path.join(ROOT, "out");

const SIZES = [
  { name: "1920x640", w: 1920, h: 640, layout: "row" },
  { name: "1500x500", w: 1500, h: 500, layout: "row" },
  { name: "1280x640", w: 1280, h: 640, layout: "row" },
  { name: "1080x1080", w: 1080, h: 1080, layout: "stack" },
];

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".woff2": "font/woff2",
  ".png": "image/png",
};

function serve(dir) {
  return new Promise((resolve) => {
    const server = createServer((req, res) => {
      const url = new URL(req.url, "http://127.0.0.1");
      let rel = decodeURIComponent(url.pathname);
      if (rel === "/") rel = "/banner.html";
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

async function main() {
  const prepared = spawnSync("python3", [path.join(__dirname, "prepare_mark.py")], {
    stdio: "inherit",
  });
  if (prepared.status !== 0) {
    throw new Error("prepare_mark.py failed");
  }
  if (!existsSync(path.join(PUBLIC, "mark.png"))) {
    throw new Error("public/mark.png missing");
  }

  mkdirSync(OUT, { recursive: true });
  const server = await serve(PUBLIC);
  const { port } = server.address();
  const origin = `http://127.0.0.1:${port}`;
  const browser = await chromium.launch({
    channel: "chrome",
    args: ["--hide-scrollbars", "--font-render-hinting=none"],
  });

  const report = [];
  try {
    for (const size of SIZES) {
      const page = await browser.newPage({
        viewport: { width: size.w, height: size.h },
        deviceScaleFactor: 1,
      });
      const url = `${origin}/banner.html?w=${size.w}&h=${size.h}&layout=${size.layout}`;
      await page.goto(url, { waitUntil: "networkidle" });
      await page.evaluate(async () => {
        await document.fonts.ready;
        const img = document.querySelector("img");
        if (img) await img.decode();
      });
      const outFile = path.join(OUT, `nosus_banner_${size.name}.png`);
      await page.locator("#banner").screenshot({ path: outFile, type: "png" });
      const text = await page.locator("#banner").innerText();
      const ok = text.includes("NO SUS");
      report.push({ ...size, outFile, ok, text: text.replace(/\s+/g, " ").trim() });
      if (!ok) console.warn("wordmark miss", size.name, text);
      else console.log("wrote", outFile);
      await page.close();
    }
  } finally {
    await browser.close();
    server.close();
  }

  writeFileSync(path.join(OUT, "render_report.json"), JSON.stringify(report, null, 2));
  if (report.some((row) => !row.ok)) process.exitCode = 2;
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
