// Single source of truth for cross-product URLs and identity.
// The marketing site owns the nosus.foo root; the Flutter web app lives at
// app.nosus.foo (see .github/workflows/gh-pages.yml). A shim in layout.tsx
// forwards legacy nosus.foo/#/... deep links to the app subdomain.
export const APP_URL = "https://app.nosus.foo/";
export const GITHUB_URL = "https://github.com/https-shubhamsahu/NON_SUS";
export const RELEASES_URL = `${GITHUB_URL}/releases/latest`;
export const PRIVACY_URL = "/privacy.html";
export const TERMS_URL = "/terms.html";
export const ACCOUNT_DELETION_URL = "/account-deletion.html";

// Supabase publishable credentials — safe to embed by design (access control
// is enforced server-side via RLS + edge functions). Must match
// lib/config/supabase_credentials.dart in the Flutter app.
export const SUPABASE_URL = "https://rxfnazmusofikwaggntb.supabase.co";
export const SUPABASE_ANON_KEY =
  "sb_publishable_4Gi8cVhWyKPcBEu69tEFrQ_Elq-uRzM";

// ── Developer identity (About-the-Developer section) ────────────────────────
export const DEVELOPER = {
  name: "Shubham Sahu",
  photo: "/founder.jpeg",
  githubHandle: "https-shubhamsahu",
  githubUrl: "https://github.com/https-shubhamsahu",
  email: "shubhamsahu9372580326@gmail.com",
  // Add more socials here as { label, url } — only entries with a url render.
  socials: [] as { label: string; url: string }[],
};
