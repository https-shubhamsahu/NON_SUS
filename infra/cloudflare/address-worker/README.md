# Address worker — `<handle>.nosus.foo`

Serves the Drop page (`nosus.foo/to`) on every handle subdomain, so
`asha.nosus.foo` works as well as `nosus.foo/to?h=asha`. The page reads the
handle from `location.hostname`; the worker only rewrites `/` to `/to` and
passes other paths (`/_next/…`, `favicon.ico`) through to the same origin.

It adds `Referrer-Policy: no-referrer`, `Content-Security-Policy:
frame-ancestors 'none'`, `X-Frame-Options: DENY`, `nosniff`, and `noindex`.
Reserved labels (`api`, `admin`, `go`, `to`, …) get a 404. `app` and `www`
are passed through untouched in case they are ever proxied by mistake.

It never sees file contents: the browser seals everything and talks to
Supabase directly.

**Status: code only, not deployed.** Until it is, the app shows only the
`nosus.foo/to?h=<handle>` form. Flip `remote_configs.address_subdomain_live`
to `true` after the steps below work end to end.

## DNS (today at name.com)

A wildcard route needs the zone on Cloudflare. Order matters, because
`app.nosus.foo` carries Android App Links verification
(`/.well-known/assetlinks.json` on GitHub Pages) and must not change
behaviour.

1. In Cloudflare, add the site `nosus.foo` (Free plan). Let it import the
   existing records from name.com. Before switching nameservers, check the
   imported list against name.com line by line:
   - apex `nosus.foo`: the four GitHub Pages `A` records (185.199.108–111.153)
     and any `AAAA` records — **DNS only (grey cloud)**.
   - `www` CNAME → `https-shubhamsahu.github.io` — **DNS only**.
   - `app` CNAME → `https-shubhamsahu.github.io` — **DNS only**. Proxying it
     would put Cloudflare's certificate and headers in front of
     `assetlinks.json`; keep it grey.
   - any `MX` / `TXT` (mail, site verification, IndexNow) copied exactly.
2. At name.com, replace the nameservers with the two Cloudflare gives you.
   Wait for Cloudflare to show the zone as Active. GitHub Pages keeps serving
   because the records are DNS-only and unchanged.
3. Check nothing moved:
   `curl -sI https://nosus.foo` and `https://app.nosus.foo` both answer from
   GitHub (`server: GitHub.com`), and
   `curl -s https://app.nosus.foo/.well-known/assetlinks.json` returns the
   same JSON as before.
4. Add the wildcard: `CNAME  *  →  nosus.foo`, **Proxied (orange cloud)**.
   Explicit records (`app`, `www`) win over the wildcard, so they stay
   DNS-only. Cloudflare's Universal SSL covers `*.nosus.foo` (one level).
5. Deploy the worker from this folder:
   `npx wrangler deploy` (needs `wrangler login` with access to the zone).
   The route `*.nosus.foo/*` only fires on proxied hostnames, so the apex and
   `app` never reach it.
6. Test: `https://test-handle.nosus.foo/` shows "This door is closed." (or
   the open door for a real handle), `https://api.nosus.foo/` is a 404, and
   the response carries `referrer-policy: no-referrer`.
7. Set `remote_configs.address_subdomain_live` to `true` so the app starts
   showing `<handle>.nosus.foo`.

Rollback: delete the `*` record (and the worker route). Nothing else depends
on it.

## Bring your own domain

For someone who wants `drop.example.com` to be their address. There is no
custom-domain hosting; the simplest honest option is an HTTPS redirect to the
NO SUS address, done at their DNS/hosting provider:

- **Cloudflare (their zone):** Rules → Redirect Rules → "Static", when
  hostname equals `drop.example.com`, redirect to
  `https://nosus.foo/to?h=<handle>` with status 302. The record for
  `drop.example.com` must be proxied (orange) for the rule to run.
- **Netlify / Vercel / GitHub Pages:** a one-page site whose only job is a
  redirect, e.g. Netlify `_redirects`: `/*  https://nosus.foo/to?h=<handle>  302`.
- **Registrar URL forwarding (name.com, Namecheap, …):** only if it forwards
  over HTTPS. Many registrar forwards are HTTP-only on the custom domain; if
  so, don't use it — the first hop would be unencrypted.

Use 302 rather than 301 so changing the handle later is not stuck in
browser caches. The redirect reveals the handle to anyone who follows it,
which is the point of an address. The door is still closed until the owner
opens it.
