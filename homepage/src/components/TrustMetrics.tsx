"use client";

import { useEffect, useState, useRef } from "react";
import { Shield, EyeOff, Key, Share2, GraduationCap, Compass, Users } from "lucide-react";
import { useInView } from "framer-motion";

function AnimatedNumber({ value }: { value: number }) {
  const [current, setCurrent] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });

  useEffect(() => {
    if (!isInView) return;
    
    let start = 0;
    const duration = 1500; // ms
    const increment = value / (duration / 16); // ~60fps
    
    const timer = setInterval(() => {
      start += increment;
      if (start >= value) {
        setCurrent(value);
        clearInterval(timer);
      } else {
        setCurrent(Math.floor(start));
      }
    }, 16);

    return () => clearInterval(timer);
  }, [value, isInView]);

  return <span ref={ref}>{current.toLocaleString()}</span>;
}

export default function TrustMetrics() {
  const trustItems = [
    { icon: EyeOff, title: "Private by Design", desc: "Access bounds are monitored without user signup requirements." },
    { icon: Key, title: "Zero Knowledge", desc: "Encryption keys are held in URL fragments and never touch the host server." },
    { icon: Shield, title: "Tamper Ledgers", desc: "Activity lists are cryptographically chained to prevent administrative edits." },
    { icon: Share2, title: "Secure Send", desc: "Custom access expiration options and download locks keep files in your custody." },
    { icon: GraduationCap, title: "For Students", desc: "Quickly distribute notes and slide decks across study groups without risk." },
    { icon: Compass, title: "For Researchers", desc: "Pre-print distribution tracking protects findings during blind peer reviews." },
    { icon: Users, title: "For Teams", desc: "Collaborate securely on sensitive plans and intellectual files." },
  ];

  // Protocol facts, not usage claims — each number is a property of the
  // system itself (verifiable in the open-source client).
  const stats = [
    { number: 256, label: "AES key bits, generated client-side" },
    { number: 0, label: "Decryption keys stored server-side" },
    { number: 1, label: "View before a burn drop self-destructs" },
    { number: 60, label: "Seconds until a revealed note wipes" },
  ];

  return (
    <section className="py-24 bg-brand-gray-dark/30 border-t border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        {/* Core Pillars Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-20">
          <div className="md:col-span-1 flex flex-col justify-center">
            <h2 className="text-3xl md:text-4xl font-black uppercase tracking-tight leading-none text-white">
              Trust Built on <br />
              Proof, Not Promises.
            </h2>
            <p className="text-xs text-brand-gray-light mt-4 leading-relaxed max-w-xs font-medium">
              We leverage browser sandboxes, local key storage, and cryptographically verified activity audits to secure your documents.
            </p>
          </div>

          <div className="md:col-span-2 grid grid-cols-1 sm:grid-cols-2 gap-6">
            {trustItems.slice(0, 4).map((item, idx) => (
              <div
                key={idx}
                className="border border-brand-gray p-6 bg-brand-black/40 hover:border-white/20 transition-colors flex flex-col gap-4 rounded"
              >
                <item.icon className="h-6 w-6 text-white stroke-[1.5]" />
                <div>
                  <h3 className="text-sm font-bold uppercase tracking-wider text-white">
                    {item.title}
                  </h3>
                  <p className="text-xs text-brand-gray-light leading-relaxed mt-1 font-medium">
                    {item.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Audit Counters Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8 pt-12 border-t border-brand-gray/60 text-center">
          {stats.map((stat, idx) => (
            <div key={idx} className="flex flex-col gap-1">
              <span className="text-3xl md:text-5xl font-black font-mono tracking-tighter text-white">
                <AnimatedNumber value={stat.number} />
              </span>
              <span className="text-[9px] font-bold uppercase tracking-widest text-brand-gray-light">
                {stat.label}
              </span>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
