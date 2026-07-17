"use client";

import { motion } from "framer-motion";

export default function Testimonials() {
  // Honest scenario cards — what the product is built for, not invented
  // customer quotes. Do not add fabricated testimonials or usage claims.
  const scenarios = [
    {
      scenario: "Sharing preprint drafts with external reviewers is nerve-wracking. Dynamic watermarking ties every viewed page to the reviewer it was sent to, so a leaked draft is traceable pre-publication.",
      author: "Researchers",
      role: "Preprints · Peer Review · Lab Notes",
    },
    {
      scenario: "Study groups share draft solutions and notes. Touch-to-reveal blur prevents passive drive-by copying, and the group audit ledger shows exactly who opened what, when.",
      author: "Study Groups",
      role: "Notes · Solution Sets · Slides",
    },
    {
      scenario: "After a client presentation, revoke access to the deck instantly. Expiry windows and view limits keep shared material under your control after it leaves your hands.",
      author: "Independent Consultants",
      role: "Decks · Proposals · Contracts",
    },
  ];

  return (
    <section id="use-cases" className="py-24 bg-brand-gray-dark/20 border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">

        <div className="text-center max-w-2xl mx-auto mb-16">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Where a Leak Actually Costs Something
          </h2>
          <p className="text-xs text-brand-gray-light mt-3 leading-relaxed font-medium">
            Scenarios the product is built for, not customer testimonials.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {scenarios.map((item, idx) => (
            <motion.div
              key={idx}
              initial={{ opacity: 0, y: 15 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: idx * 0.1 }}
              className="border border-brand-gray p-8 bg-brand-black flex flex-col justify-between min-h-[220px] rounded relative paper-card"
            >
              <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
                {item.scenario}
              </p>
              
              <div className="mt-6 border-t border-brand-gray/50 pt-4">
                <h4 className="text-xs font-bold uppercase tracking-wider text-white">
                  {item.author}
                </h4>
                <span className="text-[10px] font-mono text-brand-gray-light uppercase mt-0.5 block">
                  {item.role}
                </span>
              </div>
            </motion.div>
          ))}
        </div>

      </div>
    </section>
  );
}
