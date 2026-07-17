"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { Share2, Users, Eye, History, ShieldCheck, WifiOff, ListCollapse, Zap } from "lucide-react";

export default function FeaturesGrid() {
  const [hoveredIdx, setHoveredIdx] = useState<number | null>(null);

  const features = [
    {
      icon: Share2,
      title: "Secure File Sharing",
      desc: "Encrypt documents in-browser and share them via expiring, view-limited URLs without recipient signups.",
    },
    {
      icon: Users,
      title: "Study Groups",
      desc: "Assemble teams, sync documents, and set user permissions with complete RLS access boundaries.",
    },
    {
      icon: Eye,
      title: "Forensic Watermarks",
      desc: "Render diagonal grid watermarks identifying the viewing recipient, discouraging external captures.",
    },
    {
      icon: History,
      title: "Activity Timeline",
      desc: "Trace all document opens, downloads, and blocked leak attempts in a tamper-evident audit ledger.",
    },
    {
      icon: ShieldCheck,
      title: "Device Verification",
      desc: "Block accesses from emulators, root-broken devices, or browser inspection panels automatically.",
    },
    {
      icon: WifiOff,
      title: "Offline Access",
      desc: "Work seamlessly with local storage syncing notes and logs securely once connection is restored.",
    },
    {
      icon: ListCollapse,
      title: "Version History",
      desc: "Review past document revisions and audit changes chronologically in the system ledger.",
    },
    {
      icon: Zap,
      title: "Instant Sharing",
      desc: "Generate short-lived anonymous links instantly for quick peer review checks.",
    },
  ];

  return (
    <section id="features" className="py-24 bg-brand-gray-dark/10 border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        <div className="max-w-2xl mb-16">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white">
            Every Control, <br />
            In Detail.
          </h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {features.map((feat, idx) => (
            <motion.div
              key={idx}
              onMouseEnter={() => setHoveredIdx(idx)}
              onMouseLeave={() => setHoveredIdx(null)}
              className="relative border border-brand-gray p-8 bg-brand-black flex flex-col justify-between min-h-[250px] transition-colors rounded overflow-hidden group cursor-default"
              style={{
                borderColor: hoveredIdx === idx ? "#ffffff" : "#1e1e1e",
              }}
            >
              {/* Geometric floating accent SVG inside card */}
              <div className="absolute right-[-20px] bottom-[-20px] w-24 h-24 opacity-[0.03] group-hover:opacity-[0.08] transition-opacity duration-300 pointer-events-none">
                <svg width="100" height="100" viewBox="0 0 100 100" fill="none">
                  <rect x="10" y="10" width="80" height="80" stroke="white" strokeWidth="2" strokeDasharray="4 4" />
                </svg>
              </div>

              <div className="flex flex-col gap-4">
                <div className="w-10 h-10 border border-brand-gray flex items-center justify-center bg-brand-gray-dark rounded transition-colors group-hover:border-white">
                  <feat.icon className="h-5 w-5 text-white stroke-[1.5]" />
                </div>
                <h3 className="text-sm font-bold uppercase tracking-wider text-white">
                  {feat.title}
                </h3>
              </div>

              {/* Expand description container */}
              <p className="text-xs text-brand-gray-light leading-relaxed mt-4 font-medium">
                {feat.desc}
              </p>
              
              {/* Custom Pixel Accent trim at the bottom */}
              <div className="absolute bottom-0 left-0 right-0 h-1 bg-white scale-x-0 group-hover:scale-x-100 transition-transform origin-left duration-300" />
            </motion.div>
          ))}
        </div>

      </div>
    </section>
  );
}
