"use client";

import { useState, MouseEvent, ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Smartphone, Download, Globe, X } from "lucide-react";
import { APP_URL, RELEASES_URL } from "@/lib/links";
import { isAndroid, launchAndroidApp } from "@/lib/appLaunch";

/**
 * Zoom-style app-aware link. On desktop and iOS it is a plain anchor to the
 * web app (there is no native app to offer there). On Android it opens a
 * chooser sheet: open the installed app (with automatic fallback to the APK
 * download when it isn't installed), download the APK, or continue in the
 * browser.
 */
export default function AppLink({
  children,
  className = "",
  onNavigate,
}: {
  children: ReactNode;
  className?: string;
  /** Called when the sheet closes because navigation happened (e.g. to also close a mobile menu). */
  onNavigate?: () => void;
}) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [appMissing, setAppMissing] = useState(false);

  const handleClick = (e: MouseEvent) => {
    if (!isAndroid()) return; // plain <a> behavior
    e.preventDefault();
    setAppMissing(false);
    setSheetOpen(true);
  };

  const close = () => {
    setSheetOpen(false);
    onNavigate?.();
  };

  return (
    <>
      <a href={APP_URL} onClick={handleClick} className={className}>
        {children}
      </a>

      <AnimatePresence>
        {sheetOpen && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={close}
              className="fixed inset-0 z-[90] bg-black/70 backdrop-blur-sm"
            />

            {/* Bottom sheet */}
            <motion.div
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "spring", stiffness: 320, damping: 32 }}
              className="fixed bottom-0 left-0 right-0 z-[100] bg-brand-black border-t-2 border-white/80 rounded-t-2xl p-6 pb-8 flex flex-col gap-3"
            >
              <div className="flex items-center justify-between mb-1">
                <span className="text-[10px] font-bold tracking-widest text-white uppercase">
                  {appMissing ? "App not found on this device" : "How do you want to open NO SUS?"}
                </span>
                <button
                  onClick={close}
                  aria-label="Close"
                  className="text-brand-gray-light hover:text-white p-1"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              {!appMissing && (
                <button
                  onClick={() => launchAndroidApp(() => setAppMissing(true))}
                  className="flex items-center gap-3 bg-white text-black px-5 py-3.5 text-[11px] font-bold uppercase tracking-widest rounded-xl border border-white hover:bg-black hover:text-white transition-all"
                >
                  <Smartphone className="h-4 w-4" /> Open in the App
                </button>
              )}

              <a
                href={RELEASES_URL}
                target="_blank"
                rel="noreferrer"
                onClick={close}
                className={`flex items-center gap-3 px-5 py-3.5 text-[11px] font-bold uppercase tracking-widest rounded-xl border transition-all ${
                  appMissing
                    ? "bg-white text-black border-white hover:bg-black hover:text-white"
                    : "border-white/25 text-white hover:border-white"
                }`}
              >
                <Download className="h-4 w-4" /> Download the App (APK)
              </a>

              <a
                href={APP_URL}
                onClick={close}
                className="flex items-center gap-3 px-5 py-3.5 text-[11px] font-bold uppercase tracking-widest rounded-xl border border-white/25 text-white hover:border-white transition-all"
              >
                <Globe className="h-4 w-4" /> Continue in Browser
              </a>

              <p className="text-[9px] font-mono text-brand-gray-light leading-relaxed mt-1">
                Links you receive always open in any browser. Recipients never
                need the app.
              </p>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </>
  );
}
