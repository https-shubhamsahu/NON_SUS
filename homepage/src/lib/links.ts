// Single source of truth for cross-product URLs and identity.
// The marketing site owns the nosus.foo root; the Flutter web app lives at
// app.nosus.foo (see .github/workflows/gh-pages.yml). A shim in layout.tsx
// forwards legacy nosus.foo/#/... deep links to the app subdomain.
export const APP_URL = "https://app.nosus.foo/";
// The source repo is private. APK releases publish to the public nosus-app
// repo, which holds build output only (see play-store-release.yml).
export const RELEASES_URL =
  "https://github.com/https-shubhamsahu/nosus-app/releases/latest";
export const PRIVACY_URL = "/privacy.html";
export const TERMS_URL = "/terms.html";
export const ACCOUNT_DELETION_URL = "/account-deletion.html";

// Supabase publishable credentials — safe to embed by design (access control
// is enforced server-side via RLS + edge functions). Must match
// lib/config/supabase_credentials.dart in the Flutter app.
export const SUPABASE_URL = "https://rxfnazmusofikwaggntb.supabase.co";
export const SUPABASE_ANON_KEY =
  "sb_publishable_4Gi8cVhWyKPcBEu69tEFrQ_Elq-uRzM";

// Cloudflare Web Analytics site token for nosus.foo — public by design (it
// ships in every page). Empty turns analytics off. Loaded only by the
// legacy-link shim (src/lib/legacyLinkShim.ts), never on key-bearing URLs, and
// never in the app (app.nosus.foo / Android). Disclosed in web/privacy.html.
export const CLOUDFLARE_WEB_ANALYTICS_TOKEN = "a55650161a204c4eb063047566b2fc0e";

// ── Developer identity (About-the-Developer section) ────────────────────────
export const DEVELOPER = {
  name: "Shubham Sahu",
  photo: "/founder.webp",
  githubHandle: "https-shubhamsahu",
  githubUrl: "https://github.com/https-shubhamsahu",
  email: "shubhamsahu9372580326@gmail.com",
  // Add more socials here as { label, url } — only entries with a url render.
  socials: [] as { label: string; url: string }[],
};
