"use client";

import { useState } from "react";
import { Plus, Minus } from "lucide-react";


export default function FaqAccordion() {
  const [openIdx, setOpenIdx] = useState<number | null>(null);

  const faqs = [
    {
      q: "What is NO SUS?",
      a: "NO SUS is a secure document-sharing and private messaging platform for encrypted, self-destructing text notes (Burn Notes), anonymous encrypted file drops (Burn Files), and tracked, watermarked document link sharing (SecureSend).",
    },
    {
      q: "How secure is NO SUS?",
      a: "Burn Notes and Burn Files are encrypted in your browser with 256-bit AES (CTR mode for notes, CBC for files), and the key travels in the link's #fragment. To let a recipient unlock a drop with a 2-digit code, our server also keeps a copy of the key until that code is used or expires (20 minutes by default), then deletes it.",
    },
    {
      q: "Can I share files without creating an account?",
      a: "Yes. Our Burn Files and Burn Notes features are fully anonymous and require no account registration on either the sender or recipient end. Sharing limits apply dynamically.",
    },
    {
      q: "Can I revoke access?",
      a: "Yes. In the SecureSend link sharing dashboard, you can revoke any active share link instantly, shutting down active sessions and rendering the shared file immediately inaccessible.",
    },
    {
      q: "Can I prevent screenshots?",
      a: "On mobile clients, native screenshots and screen recorders are blocked system-wide using OS flag overrides. In browser environments where screenshot blocking is technically impossible, we use touch-to-reveal blur overlays and personalized identity watermarks to deter and trace leaks.",
    },
    {
      q: "Can governments read my files?",
      a: "It depends on the feature. Burn Notes and Burn Files are encrypted in your browser. Our server keeps a copy of a drop's key only while its 2-digit code is valid (20 minutes by default, or until the code is used), so a legal order in that window could in theory reach it; after that, we hold only ciphertext with no key. Other shared documents (SecureSend, study group files) aren't end-to-end encrypted; they're protected by strict access-control policies, but a valid legal order compelling our infrastructure provider could theoretically reach them, the same as with any cloud storage service.",
    },
    {
      q: "What happens if your servers get hacked?",
      a: "For Burn Notes and Burn Files, an attacker who breaks in while a drop's 2-digit code is still valid could find its key. Once the code is used or expires, only ciphertext with no key is left, which is useless on its own. For other stored documents, the same access-control policies that protect them from other users would need to be bypassed too, but since those files aren't end-to-end encrypted, a full breach of the storage layer could expose their contents.",
    },
    {
      q: "Can AI companies train on my files?",
      a: "No. File content is never sent to or processed by any AI or LLM service, and we don't share data with AI companies.",
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
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema).replace(/</g, "\\u003c") }}
        />

        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Frequently Asked Questions
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
                <h3>
                  <button
                    onClick={() => handleToggle(idx)}
                    className="w-full px-6 py-5 text-left flex items-center justify-between text-white font-bold uppercase text-xs tracking-wider focus:outline-none"
                    aria-expanded={isOpen}
                    aria-controls={`faq-answer-${idx}`}
                  >
                    <span>{faq.q}</span>
                    {isOpen ? <Minus className="h-4 w-4 shrink-0" /> : <Plus className="h-4 w-4 shrink-0" />}
                  </button>
                </h3>

                {/* Always in the static HTML, only hidden while collapsed, so
                    crawlers can read the answers the FAQPage schema describes. */}
                <div
                  id={`faq-answer-${idx}`}
                  hidden={!isOpen}
                  className="px-6 pb-6 pt-1 text-xs text-brand-gray-light leading-relaxed border-t border-brand-gray/40 font-medium"
                >
                  {faq.a}
                </div>
              </div>
            );
          })}
        </div>

      </div>
    </section>
  );
}
