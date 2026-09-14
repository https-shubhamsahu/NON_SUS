# Claude Design sync notes (homepage)

Project: "NO SUS Burn Ad Kit", https://claude.ai/design/p/1f11c8a0-1f58-43fa-b9aa-1bbea178e8af

Scope: the Burn ad kit only. It includes the brand tokens, Geist fonts, `NoSusLogo`, `BurnTool`, `ShareQr`, and `AppLink`. Page sections (Hero, Navbar, Footer…) are deliberately left out.

## How the build works here

- `homepage` is a Next.js app, not a library. There is no dist, and the components are default exports, which the converter's synthesized `export *` entry drops. `.design-sync/entry.ts` re-exports the four components by name. Always pass `--entry ./.design-sync/entry.ts`. To add a component, add it to `entry.ts` and `componentSrcMap`.
- The CSS is compiled separately: run `node .design-sync/build-css.mjs` (the `buildCmd`) before every converter run. It compiles `.design-sync/site.css` with the repo's own `@tailwindcss/postcss` into `.design-sync/.cache/site.css` (the `cssEntry`).
- `site.css` mirrors the tokens and base styles in `src/app/globals.css`, deliberately without the page-only rules. It scans only the synced components plus `previews/`, and adds a fixed `@source inline(...)` vocabulary so designs have layout classes. `conventions.md` documents that vocabulary; keep the two in step.
- Fonts: `next/font/google` self-hosts Geist at build time, so there is nothing in node_modules. The `.woff2` files in `.design-sync/fonts/` were copied from a `next build` (`out/_next/static/media`) on 2026-09-14. `fonts/geist.css` references them (`extraFonts`). The metric-matched "Geist Fallback" faces are `local(Arial)` rules with no file, so the converter skips them in `extraFonts`; they live in `site.css` to clear `[FONT_MISSING]`.
- `next/font` normally sets `--font-geist-sans`/`--font-geist-mono` on `<html>`; `site.css` sets them on `:root`.
- Synth mode yields empty `.d.ts` props, so all four have hand-written `dtsPropsFor` bodies. They must follow the component signatures in `src/`.
- Per-component docs (the design agent's `.prompt.md`) are authored in `.design-sync/docs/` (`docsDir`); their frontmatter sets the groups: Brand, Burn, Actions. `BurnTool.md` and `conventions.md` carry the Burn copy rules from AGENTS.md's cryptographic-honesty rule.
- Render check: no Playwright browser cache matched, so `.ds-sync` has `playwright` installed with `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, and every validate/capture/resync run needs `DS_CHROMIUM_PATH="C:/Program Files/Google/Chrome/Application/chrome.exe"`. Without it, capture crashes with a launch error.
- Windows/Git Bash: avoid `python -` in commands (the Store stub waits on stdin), and avoid apostrophes inside `node -e '…'`.

## Previews

- The preview card harness renders on white, and every NO SUS component is white-on-black. Each story wraps in a local `Stage` (`bg-brand-black p-8`).
- `BurnTool` holds its tab and text in state and takes no props. The Note and Redeem stories drive the real component on mount: they click the tab and set the textarea through the native value setter plus an `input` event. The working and READY TO SHARE states need a real upload and network, so they have no stories.
- `ShareQr` frames need `inline-flex`, or the white frame stretches the full card width.
- `BurnTool` uses `cardMode: "column"` (the circle is 380–440px wide).

## Known render warns

- None at the first sync.

## Re-sync risks

- Fonts are a copied snapshot of next/font's Geist subset files; if the site changes fonts or next/font changes subsetting, recopy them from a fresh `next build`.
- `site.css` duplicates the `@theme` tokens from `src/app/globals.css`. A token change in globals.css does not reach the kit until `site.css` is edited to match.
- `dtsPropsFor` bodies are hand-copied from the component props; a prop change in `src/` must be mirrored there.
- The Burn copy rules in `docs/BurnTool.md` and `conventions.md` mirror the product's current behavior (two-digit pairing codes, single-file homepage). If the pairing envelope port lands (key no longer held server-side on the pairing path), revisit the "server never sees the key" prohibition.
- The render check ran against system Chrome, not a Playwright-pinned Chromium.
