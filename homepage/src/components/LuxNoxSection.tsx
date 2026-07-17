"use client";

import Image from "next/image";
import { useState } from "react";
import { motion } from "framer-motion";
import { Sun, Moon } from "lucide-react";

/**
 * The lab mark: Lux (light guide) and Nox (dark guard) — the app's mascot
 * duo, documented in MASCOT_GUIDE.md at the repo root. The animation
 * language mirrors the app's: a slow "breathing" idle loop (mood 0), a
 * quick "wake" on hover (mood 2), and everything holds still under
 * prefers-reduced-motion — the same rule the Flutter client enforces via
 * the mascots' reducedMotion input.
 */
export default function LuxNoxSection() {
  const [awake, setAwake] = useState(false);

  const characters = [
    {
      icon: Sun,
      name: "LUX",
      title: "The Light Guide",
      personality: "Curious · Encouraging · Observant",
      role: "Your workspace navigator and study-desk companion. Lux keeps you oriented, pointing through onboarding, celebrating finished uploads, waiting patiently beside long jobs.",
      moods: ["guide", "celebrate", "think", "lookAround"],
    },
    {
      icon: Moon,
      name: "NOX",
      title: "The Dark Guard",
      personality: "Protective · Quiet · Alert",
      role: "The silent security sentinel. Nox appears at high-security moments, standing guard over the vault, flashing alert when a screenshot is blocked, stamping watermarks as documents are viewed.",
      moods: ["guard", "protect", "alert", "verify", "stamp"],
    },
  ];

  return (
    <section id="mascots" className="py-24 bg-brand-gray-dark/20 border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* The animated mark */}
          <div className="lg:col-span-5 flex flex-col items-center gap-6">
            <div
              className="relative flex items-center justify-center select-none"
              onMouseEnter={() => setAwake(true)}
              onMouseLeave={() => setAwake(false)}
            >
              {/* Slow-orbiting dashed ring — pixel-lab instrument vibe */}
              <div className="absolute inset-[-28px] rounded-full border border-dashed border-white/15 luxnox-ring motion-reduce:animate-none" />
              <div className="absolute inset-[-14px] rounded-full border border-white/5" />
              <motion.div
                animate={awake ? { scale: 1.06 } : { scale: 1 }}
                transition={{ type: "spring", stiffness: 260, damping: 18 }}
                className="luxnox-breathe motion-reduce:animate-none rounded-full overflow-hidden bg-white"
              >
                <Image
                  src="/luxandnox.png"
                  alt="Lux and Nox, the NO SUS lab mark: a white cat and a black cat curled into a yin-yang"
                  width={230}
                  height={230}
                  priority={false}
                />
              </motion.div>
            </div>
            <span className="text-[9px] font-mono text-brand-gray-light uppercase tracking-widest">
              {awake ? "MOOD 02 · WAKE" : "MOOD 00 · IDLE (BREATHING)"}
            </span>
          </div>

          {/* The story + character cards */}
          <div className="lg:col-span-7 flex flex-col gap-8">
            <div>
              <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
                Meet Lux &amp; Nox.
              </h2>
              <p className="text-xs text-brand-gray-light mt-4 leading-relaxed max-w-lg font-medium">
                Two cats, one mark. Inside the app they are living characters with a
                19-mood animation language, from a breathing idle loop to a sentinel
                guard stance, driven by what is actually happening to your documents.
                And they respect your reduced-motion settings, always.
              </p>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              {characters.map((c) => (
                <motion.div
                  key={c.name}
                  initial={{ opacity: 0, y: 15 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.5 }}
                  className="border border-brand-gray bg-brand-black p-6 rounded paper-card flex flex-col gap-3"
                >
                  <div className="flex items-center gap-2.5">
                    <c.icon className="h-5 w-5 text-white stroke-[1.5]" />
                    <div>
                      <h3 className="text-sm font-black uppercase tracking-widest text-white leading-none">
                        {c.name}
                      </h3>
                      <span className="text-[9px] font-mono text-brand-gray-light uppercase">
                        {c.title}
                      </span>
                    </div>
                  </div>
                  <p className="text-[10px] font-bold tracking-wider uppercase text-brand-gray-light">
                    {c.personality}
                  </p>
                  <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
                    {c.role}
                  </p>
                  <div className="flex flex-wrap gap-1.5 mt-auto pt-2">
                    {c.moods.map((m) => (
                      <span
                        key={m}
                        className="text-[8px] font-mono uppercase tracking-widest border border-brand-gray px-1.5 py-0.5 rounded-sm text-brand-gray-light"
                      >
                        {m}
                      </span>
                    ))}
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
