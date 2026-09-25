"use client";

import Image from "next/image";
import { useState } from "react";
import { Sun, Moon } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

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
      role: "The silent security sentinel. Nox appears at high-security moments, standing guard over the vault, flashing alert when a capture is blocked, stamping watermarks as documents are viewed.",
      moods: ["guard", "protect", "alert", "verify", "stamp"],
    },
  ];

  return (
    <section id="mascots" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-5 flex flex-col items-center gap-6">
            <div
              className="relative flex items-center justify-center select-none"
              onMouseEnter={() => setAwake(true)}
              onMouseLeave={() => setAwake(false)}
            >
              <div className="absolute inset-[-28px] rounded-full border border-dashed border-border luxnox-ring motion-reduce:animate-none" />
              <div className="absolute inset-[-14px] rounded-full border border-border/60" />
              <div className="luxnox-breathe motion-reduce:animate-none rounded-full overflow-hidden bg-card border border-border">
                <Image
                  src="/luxandnox.webp"
                  alt="Lux and Nox, the NO SUS lab mark: a white cat and a black cat curled into a yin-yang"
                  width={230}
                  height={230}
                  priority={false}
                />
              </div>
            </div>
            <span className="text-xs font-mono text-muted-foreground uppercase tracking-widest">
              {awake ? "MOOD 02 · WAKE" : "MOOD 00 · IDLE (BREATHING)"}
            </span>
          </div>

          <div className="lg:col-span-7 flex flex-col gap-8">
            <SectionHeader
              index="07"
              eyebrow="The mark"
              title="Meet Lux & Nox."
              lede="Two cats, one mark. Inside the app they are living characters with a 19-mood animation language, from a breathing idle loop to a sentinel guard stance, driven by what is actually happening to your documents. And they respect your reduced-motion settings, always."
            />

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              {characters.map((c) => (
                <div
                  key={c.name}
                  className="reveal paper-card p-6 flex flex-col gap-3"
                >
                  <div className="flex items-center gap-2.5">
                    <c.icon className="h-5 w-5 text-foreground stroke-[1.5]" />
                    <div>
                      <h3 className="text-base font-black uppercase tracking-widest text-foreground leading-none">
                        {c.name}
                      </h3>
                      <span className="text-xs font-mono text-muted-foreground uppercase">
                        {c.title}
                      </span>
                    </div>
                  </div>
                  <p className="text-sm font-bold tracking-wider uppercase text-muted-foreground">
                    {c.personality}
                  </p>
                  <p className="text-base text-muted-foreground leading-relaxed">
                    {c.role}
                  </p>
                  <div className="flex flex-wrap gap-1.5 mt-auto pt-2">
                    {c.moods.map((m) => (
                      <span
                        key={m}
                        className="text-xs font-mono uppercase tracking-widest border border-border px-2 py-1 rounded-[12px] text-muted-foreground"
                      >
                        {m}
                      </span>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
