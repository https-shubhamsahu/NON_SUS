# NO SUS — Final Integration & Release Report

**Prepared:** 11 July 2026 · **Scope:** whole-stack integration pass (Flutter app · Supabase backend · marketing website · CI/CD), following the documentation-first mandate: `ANALYZE_RESULT.md` (authoritative handover) and `RELEASE_REPORT.md` (10 July production audit) were treated as source of truth.

---

## 1. What this pass found and did, per layer

### 1.1 Flutter app — verified healthy, no changes needed

- `flutter analyze`: **clean** (verified at start and end of pass).
- `flutter test`: **44/44 passing, 1 skipped** (the skip requires live credentials by design).
- Feature wiring audit: every feature under `lib/features/` is reachable — 5-tab shell (Groups / Workspace / Vault / Audit / Profile), admin dashboard behind role gate in Profile, share analytics from group detail and deep link, onboarding behind AuthGate, burn note/file creators from Workspace teasers. The recently added components (`async_state_view`, `shimmer_box`, `offline_banner`, `web_links`, burn-file stack) are all imported and used — nothing orphaned.
- Placeholder scan: **zero** TODO/FIXME/dead placeholders in `lib/` (all "placeholder" matches are loading-skeleton widgets, which is the intended UX).
- FHE/Sealed subsystems: dormant behind compile-time flags defaulting to `false` (`lib/config/fhe_config.dart`) — left exactly as the docs mandate ("shelved; do not build further without founder authorization"). Their 4 edge functions are intentionally undeployed.
- Release build: `flutter build web --base-href "/"` succeeds (run in this pass). Android release readiness was already covered by `RELEASE_REPORT.md`; its manual steps remain open (see §4).

### 1.2 Supabase backend — verified, two hardening migrations applied

State verified against the live project (`rxfnazmusofikwaggntb`):

- **Migrations**: every local migration is applied remotely. The remote additionally has `enable_realtime_share_view_events` and `burn_notes_close_direct_rest_access` (applied via MCP in earlier sessions without local files) — remote is *ahead*, nothing pending. No destructive changes were made; nothing touched existing data.
- **Edge Functions**: all 8 production functions deployed and ACTIVE (`share-fetch`, `share-heartbeat`, `burn-file-init/confirm/fetch`, `cleanup-burn-files`, `drive-proxy`, `account-manager`).
- **Scheduled jobs**: 3 pg_cron sweeps active (burn-note expiry hourly, burn-file rate-limit window daily-24h hourly, burn-file cleanup every 5 min via vault-secret-authenticated edge call).
- **Buckets**: `secure-files` (private), `burn-files` (private), `avatars` (public) — as designed.

**Applied migration 1 — `20260711000000_function_grants_least_privilege.sql`:**
Every SECURITY DEFINER RPC created before the burn-files/risk-engine era carried Postgres' default `PUBLIC EXECUTE`, flagged by the security advisor (anon could invoke ~25 RPCs plus trigger functions via REST). Now: trigger functions are not client-callable at all; app RPCs are `authenticated`-only; exactly two remain anon-callable **by design** (`read_and_burn_note` — anonymous burn claims; `get_invite_details` — pre-login invite landing). Also dropped the `avatars_public_read` listing policy (file names are user ids; the app reads avatars via public object URLs, which don't consult RLS).
**Verified live after applying**: anon RPC → `42501 permission denied`; burn-note claim and invite details still 200 anonymously; avatar bucket listing returns empty; app-required grants intact.

**Applied migration 2 — `20260711010000_rls_initplan_and_fk_indexes.sql`:**
All 24 RLS policies with bare `auth.uid()` re-evaluated it per row (performance advisor). Each was rewritten with `(select auth.uid())` — quals generated mechanically from `pg_policies`, byte-identical apart from the wrap. Plus covering indexes for 3 unindexed FKs (`feedback.user_id`, `group_invites.creator_id`, `user_risk_state.tier`).

**Advisor findings accepted as-is (deliberate, documented):**
- `burn_files`/`burn_file_upload_counters` RLS-with-no-policies → intentional deny-all; access is service-role-only via edge functions.
- `burn_notes` anonymous INSERT policy → the product feature.
- `study_groups` authenticated INSERT `WITH CHECK (true)` → group creation path; tightening risks breaking creation flow for no security gain (RLS on members/files does the real gating).
- `secure-files` upload policy checks bucket only → cannot check membership because the app uploads bytes *before* inserting the metadata row; tightening requires reordering the upload flow (recommended future work, not a silent change to make in an integration pass).
- `pg_net` in `public` schema → Supabase-managed extension; relocation is riskier than the warning.

### 1.3 Marketing website (`homepage/`) — integrated, de-fictionalized, deployable

The site was untracked, undeployed, and claimed `https://nosus.foo` — a domain the Flutter app must keep forever (burn/share links in the wild resolve against the root and its URL format is a tested contract in `main.dart`). **Deployment decision:** static export (`output: "export"`, `basePath: "/home"`) served at **`nosus.foo/home/`** from the same GitHub Pages deployment. The gh-pages workflow now builds it (Node 22, `npm ci && lint && build`) and copies `out/` into `build/web/home/`.

Content integrity fixes (design language untouched — monochrome, paper/ink, pixel details, all animations preserved):

| Was | Now |
|---|---|
| Fake usage counters ("412,850 files protected", "18,450 study groups") | Protocol facts: 256 AES key bits · 0 server-side keys · 1 view per burn · 60 s note wipe |
| Testimonials from invented people ("Dr. Aris Vance") | "Built for Creators" scenario cards — same design, no fabricated attribution |
| "Developer Center" advertising a nonexistent API/SDK/CLI (`api.nosus.foo`, `@nosus/sdk-node`, `agy`) | "Under the Hood": real burn-link anatomy, the actual atomic `DELETE…RETURNING` claim, the real hash-chain formula |
| Upload demo copied a **fake share link** to visitors' clipboards | Clearly labeled "Interactive demo — your file never leaves this browser tab"; result panel routes to the real app |
| `/login`, `/signup`, `#pricing`, `#blog`, `#status`, `#help`, `#docs`, twitter.com — all dead | CTAs → `https://nosus.foo/` (the app owns auth); legal links → real hosted `privacy.html`/`terms.html`/`account-deletion.html`; dead sections removed |
| "GDPR COMPLIANT" badge, fake "System: Fully Operational" live-status, `alert("Subscribed!")` newsletter stub | "Privacy-first by design", truthful static badge, stub removed |
| Lorem ipsum in the document mockup; "Protocol v1.4" invented version | Real-looking study-notes copy; version dropped |
| `og-image.png`/`favicon.png` referenced but missing; default Next.js SVGs shipped | Missing-asset references removed; unused assets deleted |

Cross-product URLs centralized in `homepage/src/lib/links.ts`. SEO: `metadataBase`/canonical/JSON-LD now point at `nosus.foo/home`; `robots.ts` deleted (robots.txt only counts at the domain root) and replaced by **`web/robots.txt`** deployed by the Flutter build, referencing `/home/sitemap.xml`.

Verification: `npm run lint` **clean** (7 errors fixed, incl. pre-existing ones), `npm run build` **clean**, and the exact production layout (`build/web` + `build/web/home`) served locally — app shell at `/` (200), marketing site at `/home/` (200, correct title, zero fabricated strings in built output), sitemap 200, legal pages reachable.

### 1.4 CI/CD

- `gh-pages.yml`: now analyze → Flutter web build → homepage lint+build → merge → CNAME → deploy. One push to `main` ships both surfaces consistently.
- `play-store-release.yml`: verified present and correct per `RELEASE_REPORT.md`; blocked only on the four repo secrets (§4).

---

## 2. Files changed in this pass

- **New migrations** (applied to production + mirrored locally): `supabase/migrations/20260711000000_function_grants_least_privilege.sql`, `supabase/migrations/20260711010000_rls_initplan_and_fk_indexes.sql`
- **Homepage**: `next.config.ts`, `src/lib/links.ts` (new), `src/app/{layout.tsx,sitemap.ts}` (+`robots.ts` deleted), `src/components/{Navbar,Hero,UploadDropzone,TrustMetrics,Testimonials,DevSection,Footer,SecurityEditorial,LivePreview}.tsx`, `public/` cleanup
- **Web root**: `web/robots.txt` (new)
- **CI**: `.github/workflows/gh-pages.yml`
- **Docs**: `ANALYZE_RESULT.md` (architecture + resolved-issues updates), `CLAUDE.md` (homepage deployment contract), this report

Nothing was committed or pushed — the working tree also contains prior sessions' uncommitted work (Android release fixes, burn-files feature), so commit grouping is left to you.

---

## 3. Final verification checklist

- [x] Documentation read end-to-end; conflicts resolved in favor of latest (`ANALYZE_RESULT.md`, `RELEASE_REPORT.md`)
- [x] `flutter analyze` clean (start + end of pass)
- [x] `flutter test` 44/44 passing (start + end of pass)
- [x] `flutter build web` succeeds; deep-link URL contract untouched
- [x] Every `lib/features/*` surface reachable from navigation; no dead buttons, no placeholder screens, no mock leftovers (mock repos remain only as the documented offline fallback)
- [x] All animations present and wired (Rive mascots, shimmer skeletons, splash video, homepage Framer Motion set) — none replaced
- [x] Supabase: local ⊆ remote migrations; 8/8 edge functions ACTIVE; 3 cron sweeps running; realtime on `share_view_events`
- [x] Security advisors: all actionable findings fixed and live-verified; remainder documented as deliberate
- [x] Performance advisors: initplan + FK indexes fixed; unused-index INFOs left (young app, indexes will accrue usage)
- [x] Anonymous flows still work post-hardening (burn-note claim, invite details — probed over REST)
- [x] Homepage: lint clean, build clean, no fabricated content, no dead links, brand/design preserved
- [x] Combined deployment layout served and verified locally (app `/`, site `/home/`, sitemap, robots)
- [x] CI deploys both surfaces from one workflow; CNAME preserved

## 4. Requires you (cannot be done from this environment)

1. **Push to `main`** to deploy the integrated web stack (app + `/home` marketing site). Nothing has been pushed.
2. **Enable leaked-password protection** (HaveIBeenPwned check) — Supabase Dashboard → Auth → Passwords. Dashboard-only toggle; the advisor flags it.
3. **Play Store secrets** (unchanged from `RELEASE_REPORT.md` §4): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` + keystore backup + version bump before next upload.
4. **Visual click-through** of `/home/` on your machine (the local preview harness on this box can't screenshot reliably): `npx serve build/web -l 5051` → check `http://localhost:5051/home/` hero drag demo, tab panel, footer links.

---

## PHASE 2 — Landing page takes the root; app moves to a subdomain (11 July)

Per your follow-up: the marketing site now **is** `nosus.foo`, carries the real burn tools, the Lux & Nox mascots, and an About-the-Developer section, with LimeWire-style "the product itself is the hero" framing.

### Deployment topology (changed)
- **`nosus.foo`** → the Next.js landing page (static export, this repo's `gh-pages`).
- **`app.nosus.foo`** → the Flutter web app (deployed to a separate repo `nosus-app` by the same workflow).
- **Legacy links keep working.** A pre-paint shim in `layout.tsx` (and, via 404.html, path-style links) forwards `nosus.foo/#/burn|burnfile|v|join/…` and Supabase auth callbacks to `app.nosus.foo`, preserving the URL fragment (where the decryption key lives — a client-side redirect is the only way to keep it). Regex verified against all link shapes.
- Legal pages (`privacy/terms/account-deletion.html`) now ship with the landing deploy so their root URLs (referenced by Play Store + the app) keep resolving.

### Real, working burn tools on the landing page
- `BurnTool.tsx` in the hero creates **actual** Burn Notes and Burn Files against production — same client-side encryption as the app, keys only in the URL fragment.
- **Crypto compatibility proven byte-for-byte.** Extracted the app's exact formats (Burn Note = AES-256-CTR over PKCS7-padded plaintext, base64; Burn File = pack `[len][JSON][bytes]` + AES-256-CBC/PKCS7), reimplemented in WebCrypto (`homepage/src/lib/burnCrypto.ts`), and pinned them with a committed known-answer test (`test/unit/burn_crypto_web_compat_test.dart`, passing) cross-verified against WebCrypto.
- **End-to-end verified in-browser**: minted a real burn note from the page UI → 201 insert → valid `app.nosus.foo/#/burn/<uuid>?k=<64hex>&v=<32hex>` link. Also verified the note round-trips through the app's `read_and_burn_note` claim + decrypt, and (via a Node probe) the full file init→upload→confirm→fetch→decrypt cycle.
- Fixed a real robustness bug found during that test: `AnimatePresence mode="wait"` could strand a user on the "encrypting" view if the tab was backgrounded mid-mint (the link was already created). Removed `mode="wait"` on that path.

### From the app's own assets/docs
- **Lux & Nox** (`LuxNoxSection.tsx`): the `assets/icon/LuxandNox.png` mark with a breathing idle loop + wake-on-hover and a slow instrument ring, all disabled under `prefers-reduced-motion` — mirroring the app's mascot motion rules. Character copy (roles, personalities, mood names) taken from `MASCOT_GUIDE.md`.
- **About the Developer** (`DeveloperSection.tsx`): name, solo-built/zero-budget story drawn from the project docs, GitHub, email, founder photo (`assets/icon/founder_avatar.jpeg`), and an extensible socials list — all centralized in `homepage/src/lib/links.ts` for easy editing.

### App-side changes for the move
- `lib/core/utils/web_links.dart`: native share links now point at `app.nosus.foo`.
- `lib/features/config/.../config_provider.dart` + the live `remote_configs` row: "Download App" now points at GitHub Releases (the old `nosus.foo/app-release.apk` 404'd). `play-store-release.yml` now builds and attaches an APK to each release.
- `web/robots.txt`: app subdomain set to noindex (the landing page is the indexed surface).
- `gh-pages.yml`: split into independent `landing` and `app` jobs.

### ⚠️ Requires you — Phase 2 (blocking for full functionality)
1. **`BURN_FILES_IP_SALT` is not set as a Supabase edge secret** → `burn-file-init` returns 503 "not configured", so **Burn Files currently fail in production for both the app and the landing page**. I attempted to set it but the write was (correctly) blocked as an agent-generated production secret. Set it yourself: `npx supabase secrets set BURN_FILES_IP_SALT=<32+ random bytes hex>`. (Burn Notes and SecureSend are unaffected and working.)
2. **DNS**: add a CNAME record `app` → `https-shubhamsahu.github.io` so `app.nosus.foo` resolves.
3. **Create the `nosus-app` repo** (public, Pages enabled) and add an **`APP_DEPLOY_TOKEN`** secret to this repo — a PAT with `contents: write` on `nosus-app`. Without it the `app` deploy job no-ops (landing still deploys).
4. **Supabase Auth → URL Configuration**: set Site URL to `https://app.nosus.foo/` and add it (plus the existing native callback) to Redirect URLs, so email/OAuth flows land on the app, not the marketing root.
5. Everything from Phase 1 §4 still applies (leaked-password protection, Play Store secrets).

### Phase 2 verification
- [x] `homepage` lint + build clean; static export renders all new sections
- [x] Real burn-note mint verified in-browser (201 + valid app-subdomain link)
- [x] Burn note/file crypto byte-compatible app ↔ web (committed KAT test passing)
- [x] Legacy-link + auth-callback forwarding shim verified against all URL shapes
- [x] `flutter analyze` clean on changed Dart; new crypto test passing
- [ ] Visual click-through of the page — **handed to you** (this machine's preview can't screenshot reliably); run `npx serve homepage/out -l 5053`

## 5. Recommended next (not done — scope judgment)

- Reorder secure-files upload (metadata row before bytes) so the storage INSERT policy can enforce group membership; then tighten the policy.
- Accessibility Semantics/touch-target sweep in the Flutter app (`RELEASE_REPORT.md` §9) — still the largest remaining gap.
- Bundle Inter/Outfit fonts locally instead of runtime Google Fonts fetching (`RELEASE_REPORT.md` §11).
- Back-fill local SQL files for the two remote-only migrations if you ever move to `supabase db push`-based deploys.
