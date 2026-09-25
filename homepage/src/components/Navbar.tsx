"use client";

import { useState, useEffect } from "react";
import { Menu, X } from "lucide-react";
import Link from "next/link";

import { APP_URL } from "@/lib/links";
import NoSusLogo from "./ui/Logo";
import { ThemeToggle } from "./ui/ThemeToggle";
import AppLink from "./AppLink";

const navLinks = [
  { name: "Address", href: "#doors" },
  { name: "How it works", href: "#how-it-works" },
  { name: "Try it", href: "#try" },
  { name: "Security", href: "#security" },
  { name: "FAQ", href: "/#faq" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    if (!mobileMenuOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileMenuOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mobileMenuOpen]);

  return (
    <>
      <header
        className={`fixed top-0 left-0 right-0 z-50 transition-all duration-200 ease-out border-b ${
          scrolled
            ? "bg-background/90 border-border py-3 backdrop-blur-md"
            : "bg-background/90 border-transparent py-5"
        }`}
      >
        <div className="mx-auto max-w-7xl px-6 md:px-8">
          <nav className="flex items-center justify-between gap-4">
            <Link href="/" className="flex shrink-0 items-center gap-2.5 min-h-11">
              <NoSusLogo
                sizeClass="text-lg md:text-xl"
                className="!text-foreground"
              />
              <span className="hidden sm:inline-flex items-center gap-1.5 font-mono text-[10px] uppercase tracking-widest text-muted-foreground border border-border px-2 py-0.5 rounded-[4px] bg-muted/40">
                <span className="eink-live text-foreground" />
                <span>v1.4.1</span>
              </span>
            </Link>

            <ul className="hidden xl:flex items-center gap-7">
              {navLinks.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-xs font-mono font-medium uppercase tracking-wider text-muted-foreground hover:text-foreground whitespace-nowrap transition-colors duration-150"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>

            <div className="hidden xl:flex items-center gap-4">
              <ThemeToggle />
              <a
                href={APP_URL}
                className="text-xs font-semibold uppercase tracking-wider text-muted-foreground hover:text-foreground min-h-11 inline-flex items-center"
              >
                Sign in
              </a>
              <AppLink className="text-xs font-semibold uppercase tracking-wider text-muted-foreground hover:text-foreground min-h-11 inline-flex items-center">
                Get the app
              </AppLink>
              <Link
                href="/go"
                className="btn btn-primary min-h-11 px-5 text-xs"
              >
                Open on this computer
              </Link>
            </div>

            <div className="flex xl:hidden items-center gap-2">
              <ThemeToggle />
              <button
                type="button"
                onClick={() => setMobileMenuOpen((open) => !open)}
                className="inline-flex h-11 w-11 items-center justify-center text-muted-foreground hover:text-foreground"
                aria-label={mobileMenuOpen ? "Close menu" : "Open menu"}
                aria-expanded={mobileMenuOpen}
              >
                {mobileMenuOpen ? (
                  <X className="h-6 w-6" aria-hidden="true" />
                ) : (
                  <Menu className="h-6 w-6" aria-hidden="true" />
                )}
              </button>
            </div>
          </nav>
        </div>
      </header>

      {mobileMenuOpen && (
        <div className="fixed inset-0 z-40 bg-background/98 pt-28 px-6 xl:hidden flex flex-col justify-between gap-8 pb-8 overflow-y-auto">
          <div className="flex flex-col gap-6">
            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => setMobileMenuOpen(false)}
                className="inline-flex h-11 w-11 items-center justify-center text-muted-foreground hover:text-foreground"
                aria-label="Close menu"
              >
                <X className="h-6 w-6" aria-hidden="true" />
              </button>
            </div>

            <ul className="flex flex-col gap-1">
              {navLinks.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    onClick={() => setMobileMenuOpen(false)}
                    className="flex min-h-11 items-center text-lg font-bold uppercase tracking-wider text-muted-foreground hover:text-foreground"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          <div className="flex flex-col gap-3">
            <a
              href={APP_URL}
              onClick={() => setMobileMenuOpen(false)}
              className="btn btn-ghost min-h-11 w-full"
            >
              Sign in
            </a>
            <AppLink
              onNavigate={() => setMobileMenuOpen(false)}
              className="btn btn-ghost min-h-11 w-full"
            >
              Get the app
            </AppLink>
            <Link
              href="/go"
              onClick={() => setMobileMenuOpen(false)}
              className="btn btn-primary min-h-11 w-full"
            >
              Open on this computer
            </Link>
          </div>
        </div>
      )}
    </>
  );
}
