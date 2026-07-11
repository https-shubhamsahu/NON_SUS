"use client";

import { useState } from "react";
import { Plus, Minus } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";

export default function FaqAccordion() {
  const [openIdx, setOpenIdx] = useState<number | null>(null);

  const faqs = [
    {
      q: "What is NO SUS?",
      a: "NO SUS is a secure document-sharing and private messaging platform designed for zero-knowledge self-destructing text notes (Burn Notes), anonymous encrypted file drops (Burn Files), and tracked, watermarked document link sharing (SecureSend).",
    },
    {
      q: "How secure is NO SUS?",
      a: "For Zero-Knowledge drops, encryption and decryption are computed client-side using 256-bit AES-CBC. Keys reside solely in URL fragments (#hash) which are never transmitted to the database, ensuring absolute zero-knowledge containment.",
    },
    {
      q: "Can I share files without creating an account?",
      a: "Yes. Our Burn Files and Burn Notes features are fully anonymous and require no account registration on either the sender or recipient end. Sharing limits apply dynamically.",
    },
    {
      q: "What makes NO SUS different from Google Drive?",
      a: "Unlike Google Drive, NO SUS is designed for temporary, high-security transfers. We support dynamic watermarking overlays, touch-to-reveal blur barriers, browser-debugger block lists, and atomic single-use claiming databases that delete content immediately upon view.",
    },
    {
      q: "Can I revoke access?",
      a: "Yes. In the SecureSend link sharing dashboard, you can revoke any active share link instantly, shutting down active sessions and rendering the shared file immediately inaccessible.",
    },
    {
      q: "Can I prevent screenshots?",
      a: "On mobile clients, native screenshots and screen recorders are blocked system-wide using OS flag overrides. In browser environments where screenshot blocking is technically impossible, we use touch-to-reveal blur overlays and personalized identity watermarks to deter and trace leaks.",
    },
  ];

  const handleToggle = (idx: number) => {
    setOpenIdx(openIdx === idx ? null : idx);
  };

  // Structured FAQ Schema for SEO / AEO
  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": faqs.map((faq) => ({
      "@type": "Question",
      "name": faq.q,
      "acceptedAnswer": {
        "@type": "Answer",
        "text": faq.a,
      },
    })),
  };

  return (
    <section className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-4xl px-6 md:px-8">
        
        {/* Inject JSON-LD FAQ Schema */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
        />

        <div className="text-center mb-16">
          <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-2 block">
            Common Inquiries
          </span>
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Frequently Asked
          </h2>
        </div>

        <div className="flex flex-col gap-4">
          {faqs.map((faq, idx) => {
            const isOpen = openIdx === idx;
            return (
              <div
                key={idx}
                className="border border-brand-gray bg-brand-gray-dark/20 rounded overflow-hidden transition-colors"
                style={{
                  borderColor: isOpen ? "#ffffff" : "#1e1e1e",
                }}
              >
                <button
                  onClick={() => handleToggle(idx)}
                  className="w-full px-6 py-5 text-left flex items-center justify-between text-white font-bold uppercase text-xs tracking-wider focus:outline-none"
                  aria-expanded={isOpen}
                >
                  <span>{faq.q}</span>
                  {isOpen ? <Minus className="h-4 w-4 shrink-0" /> : <Plus className="h-4 w-4 shrink-0" />}
                </button>

                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0 }}
                      animate={{ height: "auto" }}
                      exit={{ height: 0 }}
                      transition={{ duration: 0.25, ease: "easeInOut" }}
                    >
                      <div className="px-6 pb-6 pt-1 text-xs text-brand-gray-light leading-relaxed border-t border-brand-gray/40 font-medium">
                        {faq.a}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            );
          })}
        </div>

      </div>
    </section>
  );
}
