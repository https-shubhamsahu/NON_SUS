"use client";

import { useState } from "react";
import { Plus, Minus } from "lucide-react";

export default function FaqAccordion() {
  const [openIdx, setOpenIdx] = useState<number | null>(null);

  const faqs = [
    {
      q: "What is NO SUS?",
      a: "NO SUS is a privacy toolkit for students: Saved chats in your Google Drive, watermarked document sharing, and self-destructing Burn Notes and Burn Files. Open Saved on a borrowed computer without signing Google in there.",
    },
    {
      q: "What is Saved?",
      a: "A chat with yourself stored in your Google Drive, in a NO SUS/ folder. The phone is the Drive client.",
    },
    {
      q: "What happens on a borrowed computer?",
      a: "You open nosus.foo/go, scan, match the 2-digit code, approve with fingerprint or face. The computer does not get your Google password or token. It only shows items you approve, for at most 60 minutes. Downloads and prints may stay on that computer. Only approve a code on a screen in front of you.",
    },
    {
      q: "Is Drop available?",
      a: "Coming soon. The door at yourname.nosus.foo is planned to stay closed until you preview and accept. It does not work yet.",
    },
    {
      q: "Are group drops available?",
      a: "Coming soon. Planned: a group feed where each member's copy is saved to their own Drive. Not available yet.",
    },
    {
      q: "Do I need an account to try a burn note?",
      a: "No.",
    },
    {
      q: "How do Burn Notes and Burn Files work?",
      a: "They are encrypted in your browser with 256-bit AES (CTR for notes, CBC for files). A normal burn link keeps the key in the URL fragment. A single note or file that uses the two-digit pairing code stores the key on the server for up to 20 minutes, then deletes it when the code is used or expires.",
    },
    {
      q: "Can I share files without creating an account?",
      a: "Yes. Burn Files and Burn Notes require no account on either the sender or recipient side. Sharing limits apply dynamically.",
    },
    {
      q: "Can I revoke access?",
      a: "Yes. In the SecureSend link sharing dashboard, you can revoke any active share link instantly, shutting down active sessions and rendering the shared file immediately inaccessible.",
    },
    {
      q: "Can I prevent screenshots?",
      a: "On mobile clients, native screenshots and screen recorders are blocked with OS flag overrides. In browsers, screenshot blocking is not possible, so we use touch-to-reveal blur overlays and personalized identity watermarks to deter and trace leaks. That is deterrence and attribution, not a guarantee that nothing can be captured.",
    },
    {
      q: "Can governments read my files?",
      a: "It depends on the feature. Burn Notes and Burn Files are encrypted in your browser. A single note or file that uses the two-digit pairing code stores the key on the server for up to 20 minutes, so a legal order in that window could in theory reach it; a normal burn link keeps the key in the URL fragment, and after the pairing window we hold only ciphertext with no key. Other shared documents (SecureSend, study group files) aren't end-to-end encrypted; they're protected by access-control policies, but a valid legal order compelling our infrastructure provider could theoretically reach them, the same as with any cloud storage service.",
    },
    {
      q: "What happens if your servers get hacked?",
      a: "For Burn Notes and Burn Files, an attacker who breaks in while a drop's two-digit pairing code is still valid could find its key (stored for up to 20 minutes). Once the code is used or expires, only ciphertext with no key is left. A normal burn link keeps the key in the URL fragment, so it was never on the server. For other stored documents, access-control policies would need to be bypassed too, and since those files aren't end-to-end encrypted, a full breach of the storage layer could expose their contents.",
    },
    {
      q: "Can AI companies train on my files?",
      a: "No. File content is never sent to or processed by any AI. We don't share data with AI companies.",
    },
  ];

  const handleToggle = (idx: number) => {
    setOpenIdx(openIdx === idx ? null : idx);
  };

  // Structured FAQ Schema for SEO / AEO — must match visible answers.
  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs.map((faq) => ({
      "@type": "Question",
      name: faq.q,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.a,
      },
    })),
  };

  return (
    <section
      id="faq"
      className="py-24 bg-background border-b border-border relative"
    >
      <div className="mx-auto max-w-4xl px-6 md:px-8">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(faqSchema).replace(/</g, "\\u003c"),
          }}
        />

        <div className="text-center mb-16">
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
            Frequently Asked Questions
          </h2>
        </div>

        <div className="flex flex-col gap-4">
          {faqs.map((faq, idx) => {
            const isOpen = openIdx === idx;
            return (
              <div
                key={idx}
                className={`paper-card border overflow-hidden transition-colors duration-200 ease-out ${
                  isOpen ? "border-foreground" : "border-border"
                }`}
              >
                <h3>
                  <button
                    type="button"
                    onClick={() => handleToggle(idx)}
                    className="w-full min-h-[44px] px-6 py-4 text-left flex items-center justify-between gap-4 text-foreground font-bold uppercase text-xs tracking-wider focus-visible:ring-2 focus-visible:ring-ring"
                    aria-expanded={isOpen}
                    aria-controls={`faq-answer-${idx}`}
                  >
                    <span>{faq.q}</span>
                    {isOpen ? (
                      <Minus className="h-4 w-4 shrink-0" aria-hidden />
                    ) : (
                      <Plus className="h-4 w-4 shrink-0" aria-hidden />
                    )}
                  </button>
                </h3>

                {/* Always in the static HTML, only hidden while collapsed, so
                    crawlers can read the answers the FAQPage schema describes. */}
                <div
                  id={`faq-answer-${idx}`}
                  hidden={!isOpen}
                  className="px-6 pb-6 pt-1 text-base text-muted-foreground leading-[1.5] border-t border-border font-medium"
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
