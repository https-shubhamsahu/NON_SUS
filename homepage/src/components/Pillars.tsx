"use client";

import { motion } from "framer-motion";
import { Shield, Radar, Fingerprint } from "lucide-react";

const pillars = [
  {
    icon: Shield,
    name: "Prevent",
    desc: "Expiring links, view limits, and device checks close the door before a leak happens.",
  },
  {
    icon: Radar,
    name: "Detect",
    desc: "Every open, download, and blocked screenshot lands in a tamper-evident timeline.",
  },
  {
    icon: Fingerprint,
    name: "Prove",
    desc: "Every viewed copy is watermarked to the person who opened it, so a leak traces back to exactly one name.",
  },
];

export default function Pillars() {
  return (
    <section className="py-24 bg-brand-gray-dark/10 border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-6xl px-6 md:px-8">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Three Jobs. One Platform.
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-px bg-brand-gray/60 border border-brand-gray/60 rounded overflow-hidden">
          {pillars.map((p, idx) => (
            <motion.div
              key={p.name}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: idx * 0.1 }}
              className="bg-brand-black p-10 flex flex-col gap-5"
            >
              <p.icon className="h-8 w-8 text-white stroke-[1.5]" />
              <h3 className="text-2xl font-black uppercase tracking-tight text-white">{p.name}</h3>
              <p className="text-sm text-brand-gray-light leading-relaxed font-medium">{p.desc}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
