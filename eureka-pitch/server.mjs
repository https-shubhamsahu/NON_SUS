import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.NOSUS_PITCH_PORT || 8787);
const host = process.env.NOSUS_PITCH_HOST || "0.0.0.0";
const sceneCount = 21;
const state = { index: 0, revision: 1, source: "server" };

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".woff2": "font/woff2",
};

function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, {
    "content-type": type,
    "cache-control": "no-store",
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "content-type",
  });
  res.end(type.startsWith("application/json") ? JSON.stringify(body) : body);
}

function body(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => { data += chunk; if (data.length > 10000) req.destroy(); });
    req.on("end", () => { try { resolve(data ? JSON.parse(data) : {}); } catch (error) { reject(error); } });
    req.on("error", reject);
  });
}

function applyCommand(command) {
  const type = command?.type;
  if (type === "next") state.index = Math.min(sceneCount - 1, state.index + 1);
  if (type === "prev") state.index = Math.max(0, state.index - 1);
  if (type === "first") state.index = 0;
  if (type === "last") state.index = sceneCount - 1;
  if (type === "goto" && Number.isInteger(command.index)) state.index = Math.max(0, Math.min(sceneCount - 1, command.index));
  state.revision += 1;
  state.source = "remote";
  return state;
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") return send(res, 204, "", "text/plain; charset=utf-8");
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  if (url.pathname === "/api/state" && req.method === "GET") return send(res, 200, state);
  if (url.pathname === "/api/state" && req.method === "POST") {
    try {
      const next = await body(req);
      if (Number.isInteger(next.index)) state.index = Math.max(0, Math.min(sceneCount - 1, next.index));
      state.revision += 1;
      state.source = "host";
      return send(res, 200, state);
    } catch { return send(res, 400, { error: "Invalid JSON" }); }
  }
  if (url.pathname === "/api/command" && req.method === "POST") {
    try { return send(res, 200, applyCommand(await body(req))); } catch { return send(res, 400, { error: "Invalid JSON" }); }
  }
  if (req.method !== "GET" && req.method !== "HEAD") return send(res, 405, { error: "Method not allowed" });
  const requested = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
  const file = path.resolve(root, `.${requested}`);
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return send(res, 404, { error: "Not found" });
  const content = fs.readFileSync(file);
  res.writeHead(200, { "content-type": mime[path.extname(file).toLowerCase()] || "application/octet-stream", "cache-control": "no-store", "access-control-allow-origin": "*" });
  if (req.method !== "HEAD") res.end(content); else res.end();
});

server.on("error", (error) => {
  if (error.code === "EADDRINUSE") {
    console.error(`Port ${port} is already in use. The NO SUS server may already be running.`);
    console.error(`Use the existing Deck URL and Phone URL, or stop the other process before restarting.`);
    process.exit(0);
  }
  console.error(error);
  process.exit(1);
});

function lanAddresses() {
  return Object.values(os.networkInterfaces()).flat().filter((item) => item && item.family === "IPv4" && !item.internal).map((item) => item.address);
}

server.listen(port, host, () => {
  console.log("NO SUS presentation server");
  console.log(`Deck:   http://localhost:${port}/`);
  console.log(`Remote: http://localhost:${port}/remote.html`);
  for (const address of lanAddresses()) console.log(`Phone:  http://${address}:${port}/remote.html`);
  console.log("Keep this terminal open during the presentation. Press Ctrl+C to stop.");
});
