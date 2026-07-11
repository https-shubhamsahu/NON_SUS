"use client";

import { useState } from "react";
import { Link2, Flame, ListTree } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { GITHUB_URL } from "@/lib/links";

export default function DevSection() {
  const [activeTab, setActiveTab] = useState<"link" | "claim" | "ledger">("link");

  const tabs = [
    { id: "link", name: "Burn Link Anatomy", icon: Link2 },
    { id: "claim", name: "One-Time Claim", icon: Flame },
    { id: "ledger", name: "Audit Chain", icon: ListTree },
  ];

  // Real mechanics, verbatim from the open-source client and schema — not a
  // product API. NO SUS has no public HTTP API, SDK, or CLI today.
  const codeBlocks = {
    link: `# A real Burn Note link, piece by piece:
https://nosus.foo/#/burn/<uuid>?k=<key>&v=<iv>
              │       │        │       │
              │       │        │       └─ 128-bit AES IV (32 hex chars)
              │       │        └─ 256-bit AES key (64 hex chars)
              │       └─ note id — the ONLY part the server knows
              └─ URL fragment: browsers never send anything after
                 "#" over the network, so the key and IV exist
                 only in your and your recipient's browsers.

# The ciphertext in the database is useless without the
# fragment — the server cannot decrypt what it stores.`,
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
-- writes and edits are revoked. Tampering with any row
-- breaks every hash after it, so the chain can be
-- re-verified end-to-end at any time.`,
  };

  return (
    <section id="developers" className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          
          {/* Left Text Detail column */}
          <div className="lg:col-span-4 flex flex-col gap-6">
            <div>
              <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-2 block">
                Under the Hood
              </span>
              <h2 className="text-3xl md:text-4xl font-black uppercase tracking-tight text-white leading-none">
                Open Mechanics. <br />
                No Trust Required.
              </h2>
            </div>

            <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
              Security claims you can check, not marketing copy. These are the actual
              link format, claim semantics, and ledger construction used in production —
              the client is open source, so every one of them is inspectable.
            </p>

            <div className="flex gap-4 border-t border-brand-gray/60 pt-6">
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noreferrer"
                className="text-xs font-bold uppercase tracking-wider text-white hover:text-brand-gray-light transition-colors"
              >
                Read the Source on GitHub
              </a>
            </div>
          </div>

          {/* Right Code Display Tab View (Column 8) */}
          <div className="lg:col-span-8 border border-brand-gray bg-brand-gray-dark/40 rounded overflow-hidden flex flex-col justify-between min-h-[380px]">
            
            {/* Tabs Header menu */}
            <div className="flex border-b border-brand-gray bg-brand-black/30">
              {tabs.map((tab) => {
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id as "link" | "claim" | "ledger")}
                    className={`flex items-center gap-2 px-6 py-4 text-[10px] font-bold uppercase tracking-widest transition-colors border-r border-brand-gray focus:outline-none ${
                      isActive
                        ? "bg-brand-gray-dark text-white border-b-2 border-b-white"
                        : "text-brand-gray-light hover:text-white bg-transparent"
                    }`}
                  >
                    <tab.icon className="h-3.5 w-3.5" />
                    {tab.name}
                  </button>
                );
              })}
            </div>

            {/* Code Panel contents */}
            <div className="flex-1 bg-brand-black p-6 font-mono text-[11px] text-brand-gray-light leading-relaxed overflow-x-auto relative">
              <div className="absolute right-4 top-4 text-[9px] text-brand-gray/40 select-none uppercase font-bold">
                {activeTab} block
              </div>
              <AnimatePresence mode="wait">
                <motion.pre
                  key={activeTab}
                  initial={{ opacity: 0, x: 5 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -5 }}
                  transition={{ duration: 0.15 }}
                  className="whitespace-pre"
                >
                  <code>{codeBlocks[activeTab]}</code>
                </motion.pre>
              </AnimatePresence>
            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
