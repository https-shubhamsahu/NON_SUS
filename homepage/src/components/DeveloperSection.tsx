"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { Mail, ArrowUpRight } from "lucide-react";
import { DEVELOPER, GITHUB_URL } from "@/lib/links";

const stack = [
  "Flutter / Dart",
  "Supabase · Postgres · RLS",
  "Deno Edge Functions",
  "Rust · TFHE-rs",
  "AES-256 client-side crypto",
  "GitHub Actions CI/CD",
];

export default function DeveloperSection() {
  return (
    <section id="developer" className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-5xl px-6 md:px-8">
        <div className="text-center mb-14">
          <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-2 block">
            About the Developer
          </span>
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            One Person, Directly Accountable.
          </h2>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="border border-brand-gray bg-brand-gray-dark/40 rounded paper-card p-8 md:p-10 grid grid-cols-1 md:grid-cols-12 gap-8 items-center"
        >
          {/* Portrait */}
          <div className="md:col-span-4 flex flex-col items-center gap-4">
            <div className="relative">
              <div className="absolute inset-[-6px] border border-dashed border-white/20 rounded" />
              <Image
                src={DEVELOPER.photo}
                alt={`${DEVELOPER.name}, developer of NO SUS`}
                width={180}
                height={180}
                className="rounded object-cover grayscale"
              />
            </div>
            <div className="text-center">
              <h3 className="text-sm font-black uppercase tracking-widest text-white">
                {DEVELOPER.name}
              </h3>
              <span className="text-[9px] font-mono text-brand-gray-light uppercase tracking-wider">
                Design · Code · Security · Ops
              </span>
            </div>
          </div>

          {/* Story */}
          <div className="md:col-span-8 flex flex-col gap-5">
            <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
              NO SUS is designed, built, and operated end-to-end by one developer:
              the Flutter client, the Postgres schema and its row-level-security
              policies, the edge functions, the cryptography, the CI pipeline, and
              this page. No growth team, no tracking SDKs, no investors to please.
            </p>
            <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
              The architecture is deliberately zero-budget: everything rides on
              free tiers, which forces the kind of design honesty this product
              preaches. The server stores ciphertext it cannot read, deletes it
              atomically on first view, and keeps a hash-chained ledger nobody can
              quietly edit. The entire client is open source; check the claims
              yourself.
            </p>

            <div className="flex flex-wrap gap-1.5">
              {stack.map((s) => (
                <span
                  key={s}
                  className="text-[8px] font-mono uppercase tracking-widest border border-brand-gray px-2 py-1 rounded-sm text-brand-gray-light"
                >
                  {s}
                </span>
              ))}
            </div>

            <div className="flex flex-wrap items-center gap-5 border-t border-brand-gray/60 pt-5">
              <a
                href={DEVELOPER.githubUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-white hover:text-brand-gray-light transition-colors"
              >
                <svg className="h-3.5 w-3.5 fill-current" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                  <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
                </svg>
                @{DEVELOPER.githubHandle}
              </a>
              <a
                href={`mailto:${DEVELOPER.email}`}
                className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-white hover:text-brand-gray-light transition-colors"
              >
                <Mail className="h-3.5 w-3.5" /> Contact
              </a>
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-white hover:text-brand-gray-light transition-colors"
              >
                Project Source <ArrowUpRight className="h-3.5 w-3.5" />
              </a>
              {DEVELOPER.socials.map((s) => (
                <a
                  key={s.url}
                  href={s.url}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-white hover:text-brand-gray-light transition-colors"
                >
                  {s.label} <ArrowUpRight className="h-3.5 w-3.5" />
                </a>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
