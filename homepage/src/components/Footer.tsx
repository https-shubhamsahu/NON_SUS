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
      { name: "SecureSend", href: "#features" },
      { name: "Burn Notes", href: "#features" },
      { name: "Burn Files", href: "#features" },
      { name: "Open the App", href: APP_URL },
      { name: "Android APK", href: RELEASES_URL },
    ],
    Resources: [
      { name: "How It Works", href: "#how-it-works" },
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
    <footer className="bg-brand-black border-t border-brand-gray/80 relative">
      
      {/* Final CTA Section */}
      <div className="mx-auto max-w-7xl px-6 md:px-8 py-20 border-b border-brand-gray/60 text-center flex flex-col items-center">
        <h2 className="text-3xl md:text-6xl font-black uppercase tracking-tight text-white max-w-2xl leading-none">
          Ready to take control <br />
          of your documents?
        </h2>
        <p className="text-xs text-brand-gray-light mt-4 leading-relaxed max-w-sm font-medium">
          Start protecting your notes, drafts, and assets from leakage today<span className="text-white">.</span> Zero account required to begin<span className="text-white">.</span>
        </p>
        <div className="mt-8">
          <AppLink className="inline-flex items-center gap-2 bg-white text-black px-10 py-4 text-xs font-bold uppercase tracking-wider hover:bg-black hover:text-white border border-white transition-all rounded-sm group">
            Get Started Free <ArrowUpRight className="h-4 w-4 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
          </AppLink>
        </div>
      </div>

      {/* Main Sitemap Footer */}
      <div className="mx-auto max-w-7xl px-6 md:px-8 py-16 grid grid-cols-2 md:grid-cols-6 gap-8">
        
        {/* Logo & Status (Column 2 wide) */}
        <div className="col-span-2 flex flex-col justify-between gap-6">
          <div className="flex flex-col gap-3">
            <NoSusLogo sizeClass="text-lg" />
            <p className="text-[11px] text-brand-gray-light leading-relaxed max-w-xs font-medium">
              Forensic document leak prevention and zero-knowledge file distribution protocols<span className="text-white">.</span>
            </p>
          </div>

          {/* Truthful project badge — not a live status indicator */}
          <div className="inline-flex items-center gap-2 border border-brand-gray bg-brand-gray-dark/50 px-3 py-1.5 rounded w-fit select-none">
            <span className="relative inline-flex rounded-full h-2 w-2 bg-white" />
            <span className="text-[9px] font-mono font-bold tracking-wider uppercase text-brand-gray-light">
              Open Source · Zero-Knowledge Drops
            </span>
          </div>
        </div>

        {/* Footer Navigation Categories */}
        {Object.entries(footerLinks).map(([category, links]) => (
          <div key={category} className="col-span-1 flex flex-col gap-4">
            <h4 className="text-[10px] font-bold tracking-widest text-white uppercase">
              {category}
            </h4>
            <ul className="flex flex-col gap-2.5">
              {links.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-[11px] text-brand-gray-light hover:text-white transition-colors font-medium"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}

      </div>

      {/* Footer Bottom copyright area */}
      <div className="mx-auto max-w-7xl px-6 md:px-8 py-8 border-t border-brand-gray/40 flex flex-col sm:flex-row justify-between items-center gap-4 text-[10px] font-mono text-brand-gray-light">
        <span>© {currentYear} NO SUS sharing protocols<span className="text-white">.</span> All rights reserved<span className="text-white">.</span></span>
        
        {/* Social Link Badges */}
        <div className="flex gap-6 items-center">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noreferrer"
            className="hover:text-white transition-colors"
            aria-label="GitHub Repository"
          >
            <svg className="h-4 w-4 fill-current" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/>
            </svg>
          </a>
          <div className="flex items-center gap-1">
            <ShieldCheck className="h-3.5 w-3.5 text-white" />
            <span>PRIVACY-FIRST BY DESIGN</span>
          </div>
        </div>
      </div>

    </footer>
  );
}
