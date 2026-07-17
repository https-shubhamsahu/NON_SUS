"use client";

import { useState, useEffect } from "react";
import { Menu, X, ArrowUpRight } from "lucide-react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { APP_URL } from "@/lib/links";
import NoSusLogo from "./ui/Logo";
import AppLink from "./AppLink";

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

  const navLinks = [
    { name: "Features", href: "#features" },
    { name: "How It Works", href: "#how-it-works" },
    { name: "Use Cases", href: "#use-cases" },
    { name: "Lux & Nox", href: "#mascots" },
    { name: "Security", href: "#security" },
    { name: "Under the Hood", href: "#developers" },
    { name: "Developer", href: "#developer" },
  ];

  return (
    <>
      <motion.header
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.5, ease: "easeOut" }}
        className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
          scrolled
            ? "bg-brand-black/90 border-b border-brand-gray/80 py-4 backdrop-blur-md"
            : "bg-transparent py-6"
        }`}
      >
        <div className="mx-auto max-w-7xl px-6 md:px-8">
          <nav className="flex items-center justify-between">
            {/* Logo */}
            <Link href="/" className="flex items-center shrink-0 group focus:outline-none">
              <NoSusLogo sizeClass="text-lg md:text-xl" />
            </Link>

            {/* Desktop Navigation */}
            <ul className="hidden xl:flex items-center gap-7">
              {navLinks.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-xs font-medium text-brand-gray-light hover:text-white transition-colors tracking-wider uppercase focus:outline-none focus:text-white whitespace-nowrap"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>

            {/* CTAs — Sign In goes to the web app; "Open the App" is
                app-aware on Android (chooser: native app / APK / browser) */}
            <div className="hidden xl:flex items-center gap-6">
              <a
                href={APP_URL}
                className="text-xs font-semibold text-brand-gray-light hover:text-white transition-colors tracking-wider uppercase"
              >
                Sign In
              </a>
              <AppLink className="relative inline-flex items-center justify-center overflow-hidden border border-white bg-white px-5 py-2.5 text-xs font-bold tracking-wider uppercase text-black transition-all hover:bg-black hover:text-white group">
                <span className="relative z-10 flex items-center gap-1.5">
                  Open the App <ArrowUpRight className="h-3.5 w-3.5" />
                </span>
              </AppLink>
            </div>

            {/* Mobile Hamburger */}
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="xl:hidden p-1 text-brand-gray-light hover:text-white focus:outline-none"
              aria-label="Toggle mobile menu"
            >
              {mobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
            </button>
          </nav>
        </div>
      </motion.header>

      {/* Mobile Drawer */}
      <AnimatePresence>
        {mobileMenuOpen && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 z-40 bg-brand-black/98 pt-28 px-6 xl:hidden flex flex-col justify-between gap-8 pb-8 overflow-y-auto"
          >
            <ul className="flex flex-col gap-6">
              {navLinks.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    onClick={() => setMobileMenuOpen(false)}
                    className="text-lg font-bold text-brand-gray-light hover:text-white tracking-wider uppercase"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>

            <div className="flex flex-col gap-4">
              <a
                href={APP_URL}
                onClick={() => setMobileMenuOpen(false)}
                className="flex items-center justify-center border border-brand-gray py-3 text-sm font-bold tracking-wider uppercase text-white"
              >
                Sign In
              </a>
              <AppLink
                onNavigate={() => setMobileMenuOpen(false)}
                className="flex items-center justify-center bg-white py-3 text-sm font-bold tracking-wider uppercase text-black"
              >
                Open the App
              </AppLink>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
