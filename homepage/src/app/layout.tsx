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
});

// Comprehensive Technical SEO and AI Answer Engine Optimization (AEO).
// Copy is aligned to what the page actually leads with (the real, working
// Burn Note/File tool in the hero) — not generic file-sharing copy.
export const metadata: Metadata = {
  title: "NO SUS - Know Who Leaked Your Document",
  // Kept under ~155 characters so Google does not truncate it.
  description: "Every document you share is watermarked to whoever opens it, so a leak traces back to one name. Self-destructing notes and files, no login required.",
  keywords: [
    "self-destructing notes",
    "anonymous file sharing",
    "no login file sharing",
    "one-time file share",
    "temporary file sharing",
    "secure file sharing",
    "encrypted document sharing",
    "document watermarking",
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
    title: "NO SUS - Know Who Leaked Your Document",
    description: "Every shared document is watermarked to whoever opens it, with a tamper-evident audit ledger behind it. Self-destructing notes and files leave nothing behind at all.",
    url: "https://nosus.foo",
    siteName: "NO SUS",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "NO SUS: self-destructing notes, no-login file drops, watermarked document sharing",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "NO SUS - Know Who Leaked Your Document",
    description: "Every document you share is watermarked to whoever opens it. Try the self-destructing note and file tools right on the page.",
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
        "Share documents watermarked to each person who opens them, and send self-destructing notes and files without an account.",
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
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased dark`}
    >
      <head>
        <link rel="preconnect" href={SUPABASE_URL} crossOrigin="anonymous" />
        <link rel="dns-prefetch" href={SUPABASE_URL} />
      </head>
      <body className="min-h-full flex flex-col bg-brand-black text-white">
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
