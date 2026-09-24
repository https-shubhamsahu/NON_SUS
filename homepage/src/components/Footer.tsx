"use client";

import { ArrowUpRight, ShieldCheck } from "lucide-react";
import Link from "next/link";
import {
  APP_URL,
  GITHUB_URL,
  PRIVACY_URL,
  TERMS_URL,
  ACCOUNT_DELETION_URL,
  RELEASES_URL,
} from "@/lib/links";
import NoSusLogo from "./ui/Logo";
import AppLink from "./AppLink";

export default function Footer() {
  const currentYear = new Date().getFullYear();

  const footerLinks = {
    Product: [
      { name: "Open on this computer", href: "/go" },
      { name: "SecureSend", href: "#features" },
      { name: "Burn Notes", href: "#try" },
      { name: "Burn Files", href: "#try" },
      { name: "Open the App", href: APP_URL },
      { name: "Android APK", href: RELEASES_URL },
    ],
    Resources: [
      { name: "How It Works", href: "#how-it-works" },
      { name: "FAQ", href: "/#faq" },
      { name: "Security Spec", href: "#security" },
      { name: "Under the Hood", href: "#developers" },
      { name: "Meet Lux & Nox", href: "#mascots" },
    ],
    Developers: [
      { name: "GitHub Source", href: GITHUB_URL },
      { name: "Report an Issue", href: `${GITHUB_URL}/issues` },
      { name: "About the Developer", href: "#developer" },
    ],
    Company: [
      { name: "Privacy Policy", href: PRIVACY_URL },
      { name: "Terms of Service", href: TERMS_URL },
      { name: "Account Deletion", href: ACCOUNT_DELETION_URL },
    ],
  };

  return (
    <footer className="bg-background border-t border-border relative">
      {/* Final CTA Section */}
      <div className="mx-auto max-w-7xl px-6 md:px-8 py-20 border-b border-border text-center flex flex-col items-center">
        <h2 className="text-[32px] md:text-6xl font-black uppercase tracking-tight text-foreground max-w-2xl leading-none">
          Ready to take control <br />
          of your documents?
        </h2>
        <p className="text-base text-muted-foreground mt-4 leading-[1.5] max-w-sm font-medium">
          Start with a burn note, or open Saved on a borrowed computer without
          signing Google in there.
        </p>
        <div className="mt-8 flex flex-col sm:flex-row items-center gap-4">
          <AppLink className="inline-flex items-center justify-center gap-2 min-h-[44px] bg-accent text-accent-foreground px-10 py-3 text-xs font-bold uppercase tracking-wider hover:opacity-90 border border-foreground transition-all duration-200 ease-out rounded-sm group">
            Get Started Free{" "}
            <ArrowUpRight className="h-4 w-4 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
          </AppLink>
          <Link
            href="/go"
            className="inline-flex items-center justify-center min-h-[44px] px-6 py-3 text-xs font-bold uppercase tracking-wider text-foreground border border-border hover:border-foreground transition-colors duration-200 ease-out"
          >
            Open on this computer
          </Link>
        </div>
      </div>

      {/* Main Sitemap Footer */}
      <div className="mx-auto max-w-7xl px-6 md:px-8 py-16 grid grid-cols-2 md:grid-cols-6 gap-8">
        <div className="col-span-2 flex flex-col justify-between gap-6">
          <div className="flex flex-col gap-3">
            <NoSusLogo sizeClass="text-lg" />
            <p className="text-base text-muted-foreground leading-[1.5] max-w-xs font-medium">
              Your Drive on any screen — watermarked documents and self-destructing
              notes, without signing Google in on a borrowed computer.
            </p>
          </div>

          <div className="inline-flex items-center gap-2 border border-border bg-muted px-3 py-1.5 rounded-sm w-fit select-none">
            <span className="relative inline-flex rounded-full h-2 w-2 bg-foreground" />
            <span className="text-[12px] font-mono font-bold tracking-wider uppercase text-muted-foreground">
              Open Source · Self-Destructing Drops
            </span>
          </div>
        </div>

        {Object.entries(footerLinks).map(([category, links]) => (
          <div key={category} className="col-span-1 flex flex-col gap-4">
            <h3 className="text-[12px] font-bold tracking-widest text-foreground uppercase">
              {category}
            </h3>
            <ul className="flex flex-col gap-2.5">
              {links.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-base text-muted-foreground hover:text-foreground transition-colors duration-200 ease-out font-medium"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="mx-auto max-w-7xl px-6 md:px-8 py-8 border-t border-border flex flex-col sm:flex-row justify-between items-center gap-4 text-[12px] font-mono text-muted-foreground">
        <span>
          © {currentYear} NO SUS sharing protocols. All rights reserved.
        </span>

        <div className="flex gap-6 items-center">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noreferrer"
            className="hover:text-foreground transition-colors duration-200 ease-out min-h-[44px] min-w-[44px] inline-flex items-center justify-center"
            aria-label="GitHub Repository"
          >
            <svg
              className="h-4 w-4 fill-current"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
            </svg>
          </a>
          <div className="flex items-center gap-1">
            <ShieldCheck className="h-3.5 w-3.5 text-foreground" />
            <span>PRIVACY-FIRST BY DESIGN</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
