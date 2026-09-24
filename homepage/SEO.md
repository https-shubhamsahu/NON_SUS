# Homepage SEO / AEO — change log

Local source fixes for https://nosus.foo. **Not live until deploy.** Do not treat this doc as Search Console or Lighthouse results.

## Changes made (second pass follow-up)

| Change | Why |
| --- | --- |
| `/go` and `/to` override `openGraph` + `twitter` title/description/`url` | Build output showed they still inherited homepage `og:url` / OG title from `layout.tsx` |

## Changes made (first pass)

| Change | Why |
| --- | --- |
| `/go` and `/to` own title, description, self-canonical; keep `robots: noindex, nofollow` | Stop inheriting homepage canonical `https://nosus.foo/`; utility pages should not compete with the home landing |
| Sitemap: remove `new Date()` `lastModified`; keep four indexable URLs only | Build-time “freshness” was false; `/go` and `/to` stay out (noindex) |
| Add `public/llms.txt` | Concise factual machine summary; no citation guarantee |
| FAQ `id="faq"` + Navbar/Footer link to `/#faq` | Crawlable/deep-linkable FAQ section |
| Schema: `operatingSystem` → `Android, Web`; soften Go availability in SoftwareApplication description | Web app is real; Go is flag-gated (~0% / testers), not GA for all visitors |
| ThreeDoors badge: “Available now” → “In app when enabled” | Matches `nosus_address_enabled` rollout honesty |
| Terms §1 opening sentence only | Align positioning with live product (not “study group workspace”) |

## Files changed

- `homepage/src/app/go/page.tsx`
- `homepage/src/app/to/page.tsx`
- `homepage/src/app/layout.tsx` (SoftwareApplication schema only)
- `homepage/src/app/sitemap.ts`
- `homepage/src/components/ThreeDoors.tsx`
- `homepage/src/components/FaqAccordion.tsx`
- `homepage/src/components/Navbar.tsx`
- `homepage/src/components/Footer.tsx`
- `homepage/public/llms.txt` (new)
- `web/terms.html` (service description + last-updated bump)
- `homepage/SEO.md` (this file)

## Verified (local source)

- `/go` metadata: title `Open Saved — NO SUS`, unique description, `canonical: "/go"`, `robots: { index: false, follow: false }`
- `/to` metadata: title `Send a file — NO SUS`, unique description, `canonical: "/to"`, noindex
- Sitemap lists only `/`, `/privacy.html`, `/terms.html`, `/account-deletion.html`; no `lastModified: new Date()`
- FAQ section has `id="faq"`; nav + footer link `/#faq`
- Schema `operatingSystem` includes Android and Web; description does not claim Go is available to all visitors
- “Available now” removed from ThreeDoors; badge reads “In app when enabled”
- Terms opening matches Saved / watermarked docs / self-destructing notes positioning
- Live site already matches hero “Your Drive on any screen.” Favicon, og-image, apple-touch-icon, app_icon, founder.webp already HTTP 200 — not “fixed” here
- `http→https` redirect was **not** checked

## Could not verify

- Emitted HTML after `next build` / production deploy (canonical link tag on live `/go` and `/to`)
- Google Search Console indexing or rich-result status (not connected / not run)
- Lighthouse scores
- Whether App Router always emits child `alternates.canonical` over parent (expected; confirm after build/deploy)
- `www.nosus.foo` — currently does **not** resolve (not a duplicate-content problem until DNS exists)

## Remaining SEO issues

- Search Console not connected / property may be unverified
- Optional `www` only matters if you want www to work (add DNS first; then decide redirect)
- External copy still overclaims crypto (Cursor India Roadshow forum bio — zero-knowledge / FHE)
- Terms body beyond §1 still mentions older study-group framing in places; only the opening was in scope
- Hero / other CTAs still invite `/go` without repeating the flag caveat on every button (badge + schema + llms.txt carry the honesty)

## Remaining AEO / GEO opportunities

- Keep FAQ answers in static HTML (already done) and aligned with schema
- Maintain `llms.txt` when product availability changes (especially when Go rollout % rises)
- Avoid new marketing routes until claims are shippable
- Correct third-party bios and pitch decks that still say ZK / FHE / screenshot-proof browser

---

## Manual actions

MANUAL ACTION REQUIRED  
Action: Connect and verify Google Search Console for `https://nosus.foo`  
Why: Indexing, sitemap submission, and coverage reports are not available from the repo alone  
Where: [Google Search Console](https://search.google.com/search-console)  
Exact steps:  
1. Add property `https://nosus.foo` (URL-prefix or Domain).  
2. Verify with the method you prefer (DNS TXT, HTML file already under `public/` if using that token, or meta tag — do not commit secrets).  
3. After deploy of this branch, submit `https://nosus.foo/sitemap.xml`.  
Expected result: Property verified; sitemap processed without `/go` or `/to` as indexable targets  
How to verify: Coverage / Sitemaps report shows the four URLs; utility routes absent or marked excluded by noindex  

MANUAL ACTION REQUIRED  
Action: Decide whether `www.nosus.foo` should resolve  
Why: `www.nosus.foo` currently does **not** resolve — this is not a www/apex duplicate today; DNS is optional  
Where: DNS host for `nosus.foo` (and later Pages/Cloudflare redirect if you add www)  
Exact steps:  
1. Only if you want www to work: add a CNAME (or A/AAAA) for `www` to the same Pages target as apex.  
2. Then configure a single canonical host (prefer apex → https://nosus.foo) via host redirect.  
3. If you do not need www, leave DNS unset.  
Expected result: Either www stays non-resolving, or www redirects to apex with one canonical  
How to verify: `nslookup www.nosus.foo` and browser request to `http://www.nosus.foo` / `https://www.nosus.foo`  

MANUAL ACTION REQUIRED  
Action: Correct Cursor forum bio / post claims that still say zero-knowledge or FHE  
Why: Public answers and AI summaries pick up outdated crypto claims that the product does not ship  
Where: https://forum.cursor.com/t/new-event-cursor-india-roadshow-mumbai/165673  
Exact steps:  
1. Open the thread and your profile/bio or post text that mentions zero-knowledge / FHE.  
2. Replace with accurate product copy (Drive-on-any-screen / watermarked shares / client-encrypted burns — no ZK/FHE).  
3. Save.  
Expected result: Forum text no longer claims ZK or FHE  
How to verify: Re-read the public page; search the thread for “zero-knowledge” and “FHE”  

MANUAL ACTION REQUIRED  
Action: Run Rich Results Test and Meta Sharing Debugger after deploy  
Why: Confirm JSON-LD and Open Graph still parse; schema honesty changes need a live URL  
Where: [Rich Results Test](https://search.google.com/test/rich-results), [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) (or equivalent)  
Exact steps:  
1. Deploy homepage + legal HTML.  
2. Test `https://nosus.foo/` for Organization / WebSite / FAQ (and SoftwareApplication if shown).  
3. Debugger-scrape `https://nosus.foo/` for og:title / og:image.  
4. Spot-check `https://nosus.foo/go` shows noindex and self-canonical in view-source.  
Expected result: No invented Review/aggregateRating; OS shows Android + Web; Go not described as GA-for-all  
How to verify: Tool reports valid items; view-source on `/go` has `noindex` and canonical `/go`  

MANUAL ACTION REQUIRED  
Action: Deploy this repo’s homepage + `web/terms.html` copy step  
Why: Changes are local until CI/Pages publish  
Where: Normal `gh-pages` / landing workflow for this monorepo  
Exact steps: Merge/push per your release process; confirm workflow copies `web/*.html` into the site  
Expected result: Live `/`, `/go`, `/to`, `/llms.txt`, `/terms.html` match this source  
How to verify: Fetch live URLs and compare title/description/canonical/badge text  

---

## Explicit non-claims for this pass

- Did not run or pass Lighthouse / Search Console audits  
- Did not change production DNS, GitHub settings, or workflows  
- Did not “fix” assets that already return HTTP 200  
- Did not verify HTTP→HTTPS redirect behavior  
