"use client";

import { motion } from "framer-motion";
import { ArrowRight, Shield, Play } from "lucide-react";
import { APP_URL } from "@/lib/links";
import BurnTool from "./BurnTool";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex flex-col justify-center items-center pt-32 pb-24 overflow-hidden swiss-grid">
      {/* Floating Background Elements */}
      <div className="absolute inset-0 pointer-events-none z-0">
        {/* Pixel folder */}
        <motion.div
          animate={{ y: [0, -15, 0], x: [0, 10, 0] }}
          transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-1/4 left-[10%] opacity-20 border border-white/20 p-3 rounded bg-brand-black"
        >
          <div className="w-8 h-6 border-2 border-white rounded-sm relative">
            <div className="absolute top-[-4px] left-1 w-3 h-1 bg-white" />
          </div>
        </motion.div>

        {/* Paper Sheet */}
        <motion.div
          animate={{ y: [0, 12, 0], rotate: [0, 5, 0] }}
          transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
          className="absolute bottom-1/4 right-[8%] opacity-25 border border-white/10 w-12 h-16 bg-brand-gray-dark/80 p-2 flex flex-col gap-1.5"
        >
          <div className="w-full h-1 bg-white/40" />
          <div className="w-5/6 h-1 bg-white/20" />
          <div className="w-2/3 h-1 bg-white/20" />
        </motion.div>

        {/* Ink speckle */}
        <motion.div
          animate={{ scale: [1, 1.1, 1], opacity: [0.15, 0.25, 0.15] }}
          transition={{ duration: 5, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[20%] right-[15%] w-4 h-4 bg-white rounded-full blur-[1px]"
        />

        {/* Encrypted Block badge */}
        <motion.div
          animate={{ y: [0, -8, 0] }}
          transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
          className="absolute bottom-[20%] left-[12%] opacity-20 border border-dashed border-white/30 px-3 py-1.5 rounded-full font-mono text-[9px] tracking-widest"
        >
          AES-256 · KEYS IN FRAGMENT
        </motion.div>
      </div>

      <div className="relative z-10 max-w-5xl px-6 md:px-8 text-center flex flex-col items-center">
        {/* Anti-Leak Badge */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="inline-flex items-center gap-2 border border-brand-gray px-3.5 py-1.5 rounded-full bg-brand-gray-dark mb-8"
        >
          <Shield className="h-3.5 w-3.5 text-white" />
          <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase">
            No Sus Sharing Protocol
          </span>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1 }}
          className="text-5xl md:text-8xl font-black tracking-tighter uppercase leading-[0.9] text-white select-none max-w-4xl"
        >
          Secure Documents. <br />
          <span className="text-brand-gray-light">Without Compromise.</span>
        </motion.h1>

        {/* Sub-paragraph */}
        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.2 }}
          className="mt-8 text-sm md:text-lg max-w-2xl text-brand-gray-light font-medium leading-relaxed"
        >
          Self-destructing notes and file drops, encrypted in your browser before
          they leave it — plus tracked, watermarked document sharing with a
          tamper-evident audit ledger. Try it right here; no account needed.
        </motion.p>

        {/* The real tool — not a simulation */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.35 }}
          className="mt-12 w-full"
        >
          <BurnTool />
        </motion.div>

        {/* Secondary CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.5 }}
          className="mt-10 flex flex-wrap justify-center gap-4 z-10"
        >
          <a
            href={APP_URL}
            className="flex items-center gap-2 bg-white text-black px-8 py-3.5 text-xs font-bold uppercase tracking-wider hover:bg-black hover:text-white border border-white transition-all group"
          >
            Open the Full App{" "}
            <ArrowRight className="h-4 w-4 group-hover:translate-x-1 transition-transform" />
          </a>
          <a
            href="#live-preview"
            className="flex items-center gap-2 border border-brand-gray px-8 py-3.5 text-xs font-bold uppercase tracking-wider hover:border-white transition-colors"
          >
            <Play className="h-3.5 w-3.5" /> See the Vault
          </a>
        </motion.div>
      </div>
    </section>
  );
}
