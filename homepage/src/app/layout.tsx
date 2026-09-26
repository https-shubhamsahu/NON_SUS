import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import {
  APP_URL,
  CLOUDFLARE_WEB_ANALYTICS_TOKEN,
  DEVELOPER,
  GITHUB_URL,
  SUPABASE_URL,
} from "@/lib/links";
import { legacyLinkShim } from "@/lib/legacyLinkShim";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
  // Labels only, never the LCP text: don't compete with Geist Sans for bandwidth.
  preload: false,
});

// Comprehensive Technical SEO and AI Answer Engine Optimization (AEO).
// Copy gives every feature equal weight and stays inside the real crypto.
export const metadata: Metadata = {
  title: "NO SUS — Burn notes, watermarked shares, your Drive anywhere",
  // 137 characters — under the 155-char soft limit so Google does not truncate it.
  description:
    "Send self-destructing notes and files from your browser, watermark documents to whoever opens them, and open your Drive on a borrowed PC.",
  keywords: [
    "google drive on borrowed computer",
    "self-destructing notes",
    "anonymous file sharing",
    "no login file sharing",
    "document watermarking",
    "secure file sharing",
    "encrypted document sharing",
    "study group collaboration",
    "privacy-first file sharing",
  ],
  metadataBase: new URL("https://nosus.foo"),
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/favicon.ico",
    apple: "/apple-touch-icon.png",
  },
  openGraph: {
    title: "NO SUS — Burn notes, watermarked shares, your Drive anywhere",
    description:
      "Send self-destructing notes and files from your browser, watermark documents to whoever opens them, and open your Drive on a borrowed PC.",
    url: "https://nosus.foo",
    siteName: "NO SUS",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "NO SUS: self-destructing notes, watermarked documents, Saved on any screen",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "NO SUS — Burn notes, watermarked shares, your Drive anywhere",
    description:
      "Send self-destructing notes and files from your browser, watermark documents to whoever opens them, and open your Drive on a borrowed PC.",
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export const viewport = {
  themeColor: "#080808",
};

// One linked graph. WebSite supplies the site name Google shows in results
// (NOSUS as an alternate, since "no sus" alone is common slang). The
// Organization logo must be at least 112px square, so it is the 512px app
// icon: /favicon.png is 32px, and web/favicon.png overwrites it at deploy.
// Keep every claim true. The only native app is Android; iOS uses the web app.
const SITE_URL = "https://nosus.foo/";
const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}#website`,
      url: SITE_URL,
      name: "NO SUS",
      alternateName: ["NOSUS", "nosus.foo"],
      inLanguage: "en",
      publisher: { "@id": `${SITE_URL}#organization` },
    },
    {
      "@type": "Organization",
      "@id": `${SITE_URL}#organization`,
      name: "NO SUS",
      url: SITE_URL,
      logo: {
        "@type": "ImageObject",
        url: `${SITE_URL}app_icon.png`,
        width: 512,
        height: 512,
      },
      founder: { "@id": `${SITE_URL}#founder` },
      sameAs: [GITHUB_URL],
    },
    {
      "@type": "Person",
      "@id": `${SITE_URL}#founder`,
      name: DEVELOPER.name,
      url: `${SITE_URL}#developer`,
      sameAs: [DEVELOPER.githubUrl, ...DEVELOPER.socials.map((s) => s.url)],
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}#app`,
      name: "NO SUS",
      url: APP_URL,
      applicationCategory: "SecurityApplication",
      operatingSystem: "Android, Web",
      image: `${SITE_URL}og-image.png`,
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
      publisher: { "@id": `${SITE_URL}#organization` },
      description:
        "Self-destructing notes and files encrypted in the browser, documents watermarked to whoever opens them, and Saved on a borrowed computer without signing Google in there. Web app at app.nosus.foo; native Android app.",
    },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      // The theme script below sets data-theme before React hydrates.
      suppressHydrationWarning
    >
      <head>
        <link rel="preconnect" href={SUPABASE_URL} crossOrigin="anonymous" />
        <link rel="dns-prefetch" href={SUPABASE_URL} />
      </head>
      <body className="min-h-full flex flex-col bg-background text-foreground">
        {/* Legacy-link shim + analytics gate — MUST run before anything
            paints. Forwards legacy app links (key material in the fragment)
            to app.nosus.foo, and is the only place Cloudflare Web Analytics
            loads, so the beacon never runs on a key-bearing URL. See
            src/lib/legacyLinkShim.ts. */}
        <script
          dangerouslySetInnerHTML={{
            __html: legacyLinkShim(CLOUDFLARE_WEB_ANALYTICS_TOKEN),
          }}
        />
        {/* Saved theme choice (ThemeToggle, key nosus-theme) applied before
            first paint, so a light pick on a dark OS doesn't flash dark. */}
        <script
          dangerouslySetInnerHTML={{
            __html:
              'try{var t=localStorage.getItem("nosus-theme");if(t==="light"||t==="dark")document.documentElement.dataset.theme=t}catch(e){}',
          }}
        />
        {/* Speculation Rules (Chromium): prefetch /go, /to and the web app when
            a link to them is hovered or pressed. Plain JSON — no JS cost;
            other browsers ignore it. app.nosus.foo is same-site. */}
        <script
          type="speculationrules"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              prefetch: [
                {
                  urls: ["/go", "/to", APP_URL],
                  eagerness: "moderate",
                },
              ],
            }),
          }}
        />
        {/* Structured Data / JSON-LD for Search & AI Engines */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(structuredData).replace(/</g, "\\u003c"),
          }}
        />
        {children}
      </body>
    </html>
  );
}
