import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import LenisProvider from "@/components/ui/LenisProvider";
import TextureBg from "@/components/ui/TextureBg";

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
  title: "NO SUS — Self-Destructing Notes & Secure Sharing",
  description: "Create real self-destructing notes and anonymous file drops — no login. Tracked, watermarked document sharing with a tamper-evident audit ledger.",
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
    title: "NO SUS — No-Login Self-Destructing Notes & File Drops",
    description: "Zero-knowledge file drop and watermarked links with real-time audit ledger. Designed for students, researchers, and secure teams.",
    url: "https://nosus.foo",
    siteName: "NO SUS",
    locale: "en_US",
    type: "website",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "NO SUS — self-destructing notes, no-login file drops, watermarked document sharing",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "NO SUS — Self-Destructing Notes & Secure Sharing",
    description: "Real self-destructing notes and anonymous file drops — no login required. Try it right on the page.",
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
      <body className="min-h-full flex flex-col bg-brand-black text-white">
        {/* Legacy-link shim — MUST run before anything paints. The Flutter
            app used to live at this root; burn/share/invite links in the
            wild (and Supabase auth callbacks) resolve against it. Key
            material rides in the hash fragment, which never reaches any
            server, so only a client-side redirect can preserve it. This
            layout also wraps 404.html, covering path-style legacy links. */}
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{
var h=window.location.hash||"",p=window.location.pathname||"/",s=window.location.search||"";
var appHash=/^#\\/?(burn|burnfile|v|join)\\//.test(h);
var appPath=/^\\/(burn|burnfile|v|join)\\//.test(p);
var authCb=/(access_token|refresh_token|error_description|type=recovery)/.test(h)||/[?&]code=/.test(s);
if(appHash||appPath||authCb){window.location.replace("https://app.nosus.foo"+(appPath?p:"/")+s+h);}
}catch(e){}})();`,
          }}
        />
        {/* Structured Data / JSON-LD for Search & AI Engines */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              "name": "NO SUS",
              "operatingSystem": "Android, iOS, Web",
              "applicationCategory": "SecurityApplication, BusinessApplication",
              "image": "https://nosus.foo/og-image.png",
              "offers": {
                "@type": "Offer",
                "price": "0",
                "priceCurrency": "USD",
              },
              "description": "Secure document sharing platform featuring forensic watermarks, touch-to-reveal blur overlays, and single-use self-destructing file drops.",
            }),
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "Organization",
              "name": "NO SUS",
              "url": "https://nosus.foo",
              "logo": "https://nosus.foo/favicon.png",
              "sameAs": [
                "https://github.com/https-shubhamsahu/NON_SUS",
              ],
            }),
          }}
        />
        <LenisProvider>
          <TextureBg />
          {children}
        </LenisProvider>
      </body>
    </html>
  );
}
