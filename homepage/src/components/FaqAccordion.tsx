import { Plus } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

export default function FaqAccordion() {

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
      a: "You open nosus.foo/go, scan, pick the 2-digit code that computer shows, and approve with your phone's screen lock. The computer does not get your Google password or token. It only shows items you approve, for at most 60 minutes. Downloads and prints may stay on that computer. Only approve a code on a screen in front of you.",
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
      a: "They are encrypted in your browser with 256-bit AES (CTR for notes, CBC for files). The direct link keeps the key in the URL fragment. Each single note or file also gets a two-digit pairing code, and while that code is valid (20 minutes by default) its key is stored on the server too. The key is swept within about 10 minutes after the code is used or expires.",
    },
    {
      q: "Can I share files without creating an account?",
      a: "Yes. Burn Files and Burn Notes require no account on either the sender or recipient side. Size limits apply: one file up to 25 MB on this page.",
    },
    {
      q: "Can I revoke access?",
      a: "Yes. In the SecureSend link sharing dashboard, you can revoke any active share link instantly, shutting down active sessions and rendering the shared file immediately inaccessible.",
    },
    {
      q: "Can I prevent screenshots?",
      a: "In the Android app, native screenshots and screen recorders are blocked with OS flag overrides. In browsers, screenshot blocking is not possible, so we use touch-to-reveal blur overlays and personalized identity watermarks to deter and trace leaks. That is deterrence and attribution, not a guarantee that nothing can be captured.",
    },
    {
      q: "Can governments read my files?",
      a: "It depends on the feature. Burn Notes and Burn Files are encrypted in your browser. Each single note or file also gets a two-digit pairing code that keeps its key on the server while the code is valid (20 minutes by default), so a legal order in that window could in theory reach it. Once the code is used or expires and the key is swept, we hold only ciphertext with no key. Other shared documents (SecureSend, study group files) aren't end-to-end encrypted; they're protected by access-control policies, but a valid legal order compelling our infrastructure provider could theoretically reach them, the same as with any cloud storage service.",
    },
    {
      q: "What happens if your servers get hacked?",
      a: "For Burn Notes and Burn Files, an attacker who breaks in while a drop's two-digit pairing code is still valid (20 minutes by default) could find its key, whichever link you shared. Once the code is used or expires and the key is swept, only ciphertext with no key is left. For other stored documents, access-control policies would need to be bypassed too, and since those files aren't end-to-end encrypted, a full breach of the storage layer could expose their contents.",
    },
    {
      q: "Can AI companies train on my files?",
      a: "No. File content is never sent to or processed by any AI. We don't share data with AI companies.",
    },
  ];

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
      className="relative border-b border-border bg-background py-20 md:py-28"
    >
      <div className="mx-auto max-w-4xl px-6 md:px-8">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify(faqSchema).replace(/</g, "\\u003c"),
          }}
        />

        <SectionHeader
          index="09"
          eyebrow="FAQ"
          title="Straight answers."
          lede="Including the uncomfortable ones: legal orders, breaches, and what a browser can't stop."
          align="center"
          className="mb-12 md:mb-16"
        />

        <div className="flex flex-col border-t border-border">
          {/* Native <details>: no JavaScript, and every answer the FAQPage schema
              describes is in the static HTML. name="faq" keeps one open at a
              time where supported. */}
          {faqs.map((faq, idx) => (
            <details key={idx} name="faq" className="group border-b border-border">
              <summary className="flex min-h-[56px] cursor-pointer list-none items-center justify-between gap-6 py-5 text-left text-base font-bold tracking-[-0.01em] text-foreground transition-colors duration-150 hover:text-muted-foreground md:text-lg [&::-webkit-details-marker]:hidden">
                <h3>{faq.q}</h3>
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full border border-border text-foreground">
                  <Plus
                    className="h-4 w-4 transition-transform duration-200 ease-out group-open:rotate-45 motion-reduce:transition-none"
                    aria-hidden
                  />
                </span>
              </summary>
              <p className="max-w-3xl pb-6 pr-12 text-base leading-relaxed text-muted-foreground">
                {faq.a}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
