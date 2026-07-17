"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import { Upload, Shield, Share2, Users, Eye, Ban } from "lucide-react";

export default function WorkflowTimeline() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
  });

  // Translate horizontal track based on vertical scroll progress
  const x = useTransform(scrollYProgress, [0, 1], ["0%", "-60%"]);

  const steps = [
    {
      icon: Upload,
      num: "01",
      title: "Upload",
      desc: "Drag or select your document. Files are encrypted client-side using AES-256 before reaching the server.",
    },
    {
      icon: Shield,
      num: "02",
      title: "Protect",
      desc: "Apply dynamic email watermarks, toggle touch-to-reveal blur, and enable root-detection filters.",
    },
    {
      icon: Share2,
      num: "03",
      title: "Share",
      desc: "Mint secure access URLs. Control links with automatic revocation bounds, view counts, and expiration limits.",
    },
    {
      icon: Users,
      num: "04",
      title: "Collaborate",
      desc: "Roster students or researchers into secure groups. Keep notes sync'd in real-time, online or offline.",
    },
    {
      icon: Eye,
      num: "05",
      title: "Track",
      desc: "Monitor opens, durations, and suspicious actions like right-clicks or screenshot attempts on a chained log.",
    },
    {
      icon: Ban,
      num: "06",
      title: "Control",
      desc: "Instantly revoke share permissions or self-destruct documents, wiping them from cache and storage.",
    },
  ];

  return (
    <div ref={containerRef} id="how-it-works" className="relative h-[250vh] bg-brand-black">
      {/* Sticky screen container */}
      <div className="sticky top-0 h-screen overflow-hidden flex flex-col justify-center">
        
        <div className="mx-auto max-w-7xl w-full px-6 md:px-8 mb-12">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            End-to-End Governance
          </h2>
        </div>

        {/* Horizontal scroll track */}
        <div className="relative w-full flex items-center">
          <motion.div style={{ x }} className="flex gap-8 px-6 md:px-12 w-[160vw] md:w-[130vw]">
            {steps.map((step, idx) => (
              <div
                key={idx}
                className="w-[280px] md:w-[350px] shrink-0 border border-brand-gray bg-brand-gray-dark/50 p-8 rounded flex flex-col justify-between min-h-[300px] relative"
              >
                {/* Connector dotted line */}
                {idx < steps.length - 1 && (
                  <div className="absolute top-[52px] right-[-32px] w-8 border-t border-dashed border-brand-gray/60 z-0 hidden md:block" />
                )}

                <div className="flex justify-between items-start">
                  <div className="w-12 h-12 border border-brand-gray flex items-center justify-center bg-brand-black rounded">
                    <step.icon className="h-5 w-5 text-white stroke-[1.5]" />
                  </div>
                  <span className="font-mono text-3xl font-black text-brand-gray/30">
                    {step.num}
                  </span>
                </div>

                <div className="mt-8">
                  <h3 className="text-base font-bold uppercase tracking-wider text-white">
                    {step.title}
                  </h3>
                  <p className="text-xs text-brand-gray-light leading-relaxed mt-2 font-medium">
                    {step.desc}
                  </p>
                </div>
              </div>
            ))}
          </motion.div>
        </div>

        {/* Scroll indicator overlay */}
        <div className="absolute bottom-12 left-1/2 -translate-x-1/2 flex flex-col items-center gap-1">
          <span className="text-[9px] font-bold tracking-widest uppercase text-brand-gray-light">
            Scroll down to advance
          </span>
          <motion.div
            animate={{ y: [0, 5, 0] }}
            transition={{ duration: 1.5, repeat: Infinity }}
            className="w-1 h-3 bg-brand-gray-light rounded-full"
          />
        </div>

      </div>
    </div>
  );
}
