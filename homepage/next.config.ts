import type { NextConfig } from "next";

// Statically exported and served at the nosus.foo ROOT (GitHub Pages). The
// Flutter web app lives at app.nosus.foo; layout.tsx carries a shim that
// forwards legacy nosus.foo deep links (burn/burnfile/v/join + auth
// callbacks) to the app subdomain. See .github/workflows/gh-pages.yml.
const nextConfig: NextConfig = {
  output: "export",
  images: { unoptimized: true },
};

export default nextConfig;
