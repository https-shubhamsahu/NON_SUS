import { ArrowRight, ArrowUpRight } from "lucide-react";
import Link from "next/link";
import {
  APP_URL,
  DEVELOPER,
  PRIVACY_URL,
  TERMS_URL,
  ACCOUNT_DELETION_URL,
  RELEASES_URL,
} from "@/lib/links";
import NoSusLogo from "./ui/Logo";

const footerLinks = {
  Product: [
    { name: "Open on this computer", href: "/go" },
    { name: "Burn Notes & Files", href: "/#try" },
    { name: "SecureSend", href: "/#sharing" },
    { name: "Open the web app", href: APP_URL },
    { name: "Android APK", href: RELEASES_URL },
  ],
  Learn: [
    { name: "How Go works", href: "/#how-it-works" },
    { name: "Security", href: "/#security" },
    { name: "Under the hood", href: "/#developers" },
    { name: "FAQ", href: "/#faq" },
  ],
  Project: [
    { name: "Report an issue", href: `mailto:${DEVELOPER.email}?subject=NO%20SUS%20issue` },
    { name: "About the maker", href: "/#developer" },
  ],
  Legal: [
    { name: "Privacy Policy", href: PRIVACY_URL },
    { name: "Terms of Service", href: TERMS_URL },
    { name: "Account deletion", href: ACCOUNT_DELETION_URL },
  ],
};

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="relative border-t border-border bg-background">
      {/* Closing call to action */}
      <div className="relative overflow-hidden border-b border-border">
        <div className="relative mx-auto flex max-w-7xl flex-col items-start gap-8 px-6 py-20 md:px-8 md:py-28">
          <p className="eyebrow">
            <span className="eyebrow-index" aria-hidden="true">→</span>
            <span className="eyebrow-rule" aria-hidden="true" />
            <span>Start here</span>
          </p>
          <h2 className="max-w-4xl text-[40px] font-black leading-[1] tracking-[-0.04em] text-foreground md:text-7xl">
            Your files. Your phone.
            <br />
            <span className="text-muted-foreground">Any screen.</span>
          </h2>
          <p className="max-w-xl text-base leading-relaxed text-muted-foreground md:text-lg">
            Try a burn note right here — no account. Or get the app and open
            Saved on a borrowed computer once Go is enabled for you.
          </p>
          <div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">
            <Link href="/#try" className="btn btn-primary group min-h-12 px-6">
              Try a burn note
              <ArrowRight className="nudge h-4 w-4" aria-hidden />
            </Link>
            <a href={RELEASES_URL} className="btn btn-ghost min-h-12 px-6">Get the Android app</a>
            <a href={APP_URL} className="btn btn-ghost group min-h-12 px-6">
              Open the web app
              <ArrowUpRight className="nudge h-4 w-4" aria-hidden />
            </a>
          </div>
        </div>
      </div>

      {/* Sitemap */}
      <div className="mx-auto grid max-w-7xl grid-cols-2 gap-10 px-6 py-16 md:grid-cols-6 md:px-8">
        <div className="col-span-2 flex flex-col gap-4">
          <NoSusLogo sizeClass="text-xl" />
          <p className="max-w-xs text-sm leading-relaxed text-muted-foreground">
            Self-destructing notes and files, watermarked documents, and your
            Drive on a borrowed screen. Designed, built and run by one developer.
          </p>
        </div>

        {Object.entries(footerLinks).map(([category, links]) => (
          <nav key={category} aria-label={category} className="col-span-1 flex flex-col gap-4">
            <h3 className="font-mono text-xs font-bold uppercase tracking-widest text-foreground">
              {category}
            </h3>
            <ul className="flex flex-col gap-2.5">
              {links.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground transition-colors duration-150 ease-out hover:text-foreground"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>

      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 border-t border-border px-6 py-6 font-mono text-xs text-muted-foreground sm:flex-row md:px-8">
        <span>© {currentYear} NO SUS · All rights reserved</span>
        <span className="uppercase tracking-widest">nosus.foo</span>
      </div>
    </footer>
  );
}
