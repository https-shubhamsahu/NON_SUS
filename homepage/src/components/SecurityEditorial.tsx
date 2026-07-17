"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Key, Cpu, ChevronRight, HelpCircle } from "lucide-react";

export default function SecurityEditorial() {
  const [showTechnicalSpecs, setShowTechnicalSpecs] = useState(false);

  const keyStatements = [
    { title: "Only the people you choose can access your files.", desc: "Dynamic domain filters and strict user authentication keep document scopes private." },
    { title: "Every action is traceable.", desc: "Screenshot logs, DevTools notifications, and dynamic identification watermarks identify source breaches." },
    { title: "Sharing stays under your control.", desc: "Instant revocation and view counters close remote access links immediately." },
    { title: "Privacy isn't optional.", desc: "From onboarding checks to ledger chains, we bake security directly into every database state." },
  ];

  return (
    <section id="security" className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          
          {/* Editorial Content (Left Column) */}
          <div className="lg:col-span-6 flex flex-col justify-center gap-8">
            <div>
              <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
                Absolute Governance. <br />
                No Excuses.
              </h2>
            </div>

            <div className="flex flex-col gap-6">
              {keyStatements.map((state, idx) => (
                <div key={idx} className="flex gap-4 items-start">
                  <div className="w-1.5 h-1.5 bg-white rounded-full shrink-0 mt-2" />
                  <div>
                    <h3 className="text-sm font-bold uppercase tracking-wider text-white">
                      {state.title}
                    </h3>
                    <p className="text-xs text-brand-gray-light mt-1.5 leading-relaxed font-medium">
                      {state.desc}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            <div>
              <button
                onClick={() => setShowTechnicalSpecs(!showTechnicalSpecs)}
                className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-widest text-white hover:text-brand-gray-light transition-colors group focus:outline-none"
              >
                Learn More (Technical Specs)
                <ChevronRight className={`h-4 w-4 transition-transform ${showTechnicalSpecs ? "rotate-90" : "group-hover:translate-x-1"}`} />
              </button>
            </div>
          </div>

          {/* Graphic / Interactive Technical Blueprints Panel (Right Column) */}
          <div className="lg:col-span-6 border border-brand-gray bg-brand-gray-dark/40 rounded p-8 min-h-[380px] flex flex-col justify-between relative overflow-hidden">
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(255,255,255,0.01)_0%,transparent_70%)] pointer-events-none" />

            <AnimatePresence mode="wait">
              {!showTechnicalSpecs ? (
                <motion.div
                  key="ethos-card"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="flex flex-col justify-between h-full gap-8"
                >
                  <div className="flex items-center gap-2 border-b border-brand-gray pb-3">
                    <Key className="h-5 w-5 text-white" />
                    <span className="text-[10px] font-mono tracking-widest uppercase text-brand-gray-light">
                      Encryption Envelope
                    </span>
                  </div>
                  <div className="py-4">
                    <p className="text-xs text-brand-gray-light leading-relaxed font-medium">
                      For Burn Notes and Burn Files, encryption happens entirely in your browser and the key never reaches our servers, managed via the URL hash segment instead. Other shared documents are protected by strict access-control policies rather than end-to-end encryption.
                    </p>
                  </div>
                  <div className="border-t border-brand-gray pt-4 flex items-center justify-between text-[10px] font-mono text-brand-gray-light">
                    <span>ALGORITHM: AES-256-CBC</span>
                    <span>KEY SIZE: 256 BITS</span>
                  </div>
                </motion.div>
              ) : (
                <motion.div
                  key="tech-blueprint"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                  className="flex flex-col justify-between h-full gap-6 font-mono text-[10px]"
                >
                  <div className="flex items-center gap-2 border-b border-brand-gray pb-3">
                    <Cpu className="h-5 w-5 text-white" />
                    <span className="text-[10px] tracking-widest uppercase text-brand-gray-light">
                      Cryptographic Blueprint
                    </span>
                  </div>
                  
                  <div className="flex flex-col gap-4 text-brand-gray-light">
                    <div className="flex justify-between border-b border-brand-gray/30 pb-1.5">
                      <span className="text-white font-bold">1. File Encryption</span>
                      <span>In-browser AES-256-CBC</span>
                    </div>
                    <div className="flex justify-between border-b border-brand-gray/30 pb-1.5">
                      <span className="text-white font-bold">2. Key Transport</span>
                      <span>URL Fragment Identifier (#hash)</span>
                    </div>
                    <div className="flex justify-between border-b border-brand-gray/30 pb-1.5">
                      <span className="text-white font-bold">3. Access Verification</span>
                      <span>Single-use claiming SQL transactions</span>
                    </div>
                    <div className="flex justify-between border-b border-brand-gray/30 pb-1.5">
                      <span className="text-white font-bold">4. Audit Chain</span>
                      <span>SHA-256 Hash-Linked Database Rows</span>
                    </div>
                  </div>

                  <div className="border border-brand-gray/60 p-3.5 bg-brand-black/50 text-[9px] text-brand-gray-light leading-relaxed flex items-start gap-2.5 rounded">
                    <HelpCircle className="h-4.5 w-4.5 text-white shrink-0 mt-0.5" />
                    <span>
                      Keys are parsed locally by JavaScript `window.location.hash`. Browsers do not transmit this token to servers during normal HTTP operations.
                    </span>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
            
          </div>

        </div>

      </div>
    </section>
  );
}
