// Compiles .design-sync/site.css with the homepage's own Tailwind v4 PostCSS
// plugin into .design-sync/.cache/site.css (the sync's cssEntry). Run from
// homepage/ before the converter: node .design-sync/build-css.mjs
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import postcss from "postcss";
import tailwind from "@tailwindcss/postcss";

const here = dirname(fileURLToPath(import.meta.url));
const from = resolve(here, "site.css");
const to = resolve(here, ".cache/site.css");
const result = await postcss([tailwind({ base: resolve(here, "..") })]).process(
  readFileSync(from, "utf8"),
  { from, to },
);
mkdirSync(dirname(to), { recursive: true });
writeFileSync(to, result.css);
console.log(`wrote ${to} (${result.css.length} bytes)`);
