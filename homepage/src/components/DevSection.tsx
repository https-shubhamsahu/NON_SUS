"use client";

import { useState } from "react";
import { Link2, Flame, ListTree, ArrowRight } from "lucide-react";

import { DEVELOPER } from "@/lib/links";
import SectionHeader from "./ui/SectionHeader";

export default function DevSection() {
  const [activeTab, setActiveTab] = useState<"link" | "claim" | "ledger">("link");

  const tabs = [
    { id: "link", name: "Burn Link Anatomy", icon: Link2 },
    { id: "claim", name: "One-Time Claim", icon: Flame },
    { id: "ledger", name: "Audit Chain", icon: ListTree },
  ];

  const onTabKey = (e: React.KeyboardEvent<HTMLDivElement>) => {
    const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
    if (!step) return;
    e.preventDefault();
    const i = tabs.findIndex((t) => t.id === activeTab);
    const next = tabs[(i + step + tabs.length) % tabs.length].id as typeof activeTab;
    setActiveTab(next);
    document.getElementById(`dev-tab-${next}`)?.focus();
  };

  // Real mechanics, verbatim from the client and schema — not a
  // product API. NO SUS has no public HTTP API, SDK, or CLI today.
  const codeBlocks = {
    link: `# A real Burn Note link, piece by piece:
https://app.nosus.foo/#/burn/<uuid>?k=<key>&v=<iv>
              │       │        │       │
              │       │        │       └─ 128-bit AES IV (32 hex chars)
              │       │        └─ 256-bit AES key (64 hex chars)
              │       └─ note id, the ONLY part the server knows
              └─ URL fragment: browsers never send anything after
                 "#" over the network, so the key and IV exist
                 only in your and your recipient's browsers.

# The ciphertext in the database is useless without the
# fragment. (Each single note or file also mints a
# two-digit pairing code, which holds the key server-side
# while the code is valid: 20 minutes by default.)`,
    claim: `-- Claiming a burn note is one atomic statement:
DELETE FROM burn_notes
 WHERE id = <note_id>
RETURNING ciphertext;

-- The row is gone the instant it is read. Two racing
-- recipients cannot both claim it: one gets the
-- ciphertext, the other gets nothing. Decryption then
-- happens locally with the key from the URL fragment.
-- Burn files work the same way, with the encrypted
-- blob wiped from object storage by a sweeper within
-- minutes of the claim.`,
    ledger: `-- Every group event is a hash-chained ledger row:
entry_hash = sha256(
  actor_id || event_type || created_at || previous_hash
)

-- Inserted only via a SECURITY DEFINER RPC; direct
-- writes and edits are revoked. Changing a row's actor,
-- event type or time breaks every hash after it, so the
-- chain can be re-verified end-to-end at any time.`,
  };

  return (
    <section id="developers" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          
          <div className="lg:col-span-4 flex flex-col gap-6">
            <SectionHeader
              index="06"
              eyebrow="Under the hood"
              title="Open mechanics."
            />

            <p className="reveal text-base text-muted-foreground leading-relaxed">
              Security claims you can check, not marketing copy. These are the actual
              link format, claim semantics, and ledger construction used in production.
              The Burn crypto runs in your browser, so you can watch the key stay
              in the link with your browser&apos;s own dev tools.
            </p>

            <div className="flex gap-4 border-t border-border pt-6">
              <a
                href={`mailto:${DEVELOPER.email}?subject=NO%20SUS%20security%20report`}
                className="group inline-flex min-h-11 items-center gap-2 text-sm font-bold uppercase tracking-wider text-foreground hover:text-muted-foreground transition-colors"
              >
                Report a security issue
                <ArrowRight className="nudge h-4 w-4" aria-hidden />
              </a>
            </div>
          </div>

          {/* Right Code Display Tab View (Column 8) */}
          <div className="reveal lg:col-span-8 border border-border bg-card rounded-[12px] overflow-hidden flex flex-col justify-between min-h-[380px] paper-card">
            
            {/* Tabs Header menu */}
            <div role="tablist" aria-label="Mechanics" onKeyDown={onTabKey} className="flex overflow-x-auto border-b border-border bg-muted">
              {tabs.map((tab) => {
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    id={`dev-tab-${tab.id}`}
                    type="button"
                    role="tab"
                    aria-selected={isActive}
                    aria-controls="dev-panel"
                    tabIndex={isActive ? 0 : -1}
                    onClick={() => setActiveTab(tab.id as "link" | "claim" | "ledger")}
                    className={`flex shrink-0 items-center gap-2 whitespace-nowrap px-5 py-4 text-xs font-bold uppercase tracking-widest transition-colors border-r border-border ${
                      isActive
                        ? "bg-card text-foreground border-b-2 border-b-foreground"
                        : "text-muted-foreground hover:text-foreground bg-transparent"
                    }`}
                  >
                    <tab.icon className="h-4 w-4" />
                    {tab.name}
                  </button>
                );
              })}
            </div>

            {/* Code Panel contents */}
            <div
              id="dev-panel"
              role="tabpanel"
              aria-labelledby={`dev-tab-${activeTab}`}
              tabIndex={0}
              className="flex-1 bg-brand-black p-6 font-mono text-xs text-white leading-relaxed overflow-x-auto relative"
            >
              <div aria-hidden="true" className="absolute right-4 top-4 text-[10px] text-white select-none uppercase font-bold">
                {activeTab} block
              </div>
              <>
                <pre
                  key={activeTab}
                  className="whitespace-pre font-mono text-xs text-white"
                >
                  <code>{codeBlocks[activeTab]}</code>
                </pre>
              </>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
