"use client";

import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { FileText, Lock, Shield, Eye } from "lucide-react";

export default function DeviceScreenshots() {
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
  // Below `sm` only the phone mock renders (laptop/tablet are hidden), so its
  // constant +200/+80 offset (tuned for sitting beside the other two layers)
  // would otherwise shove it almost entirely off-screen. Track the viewport
  // and zero that base offset out when it's the only layer visible.
  const [showTablet, setShowTablet] = useState(true);

  useEffect(() => {
    const update = () => setShowTablet(window.innerWidth >= 640);
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    // Normalize position relative to center: -0.5 to 0.5
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    setMousePos({ x, y });
  };

  return (
    <section
      onMouseMove={handleMouseMove}
      className="py-32 bg-brand-black border-b border-brand-gray/80 relative overflow-hidden flex flex-col items-center"
    >
      <div className="mx-auto max-w-7xl px-6 md:px-8 w-full">
        
        <div className="text-center max-w-2xl mx-auto mb-20">
          <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-2 block">
            Viewport Adaptation
          </span>
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Secure Everywhere
          </h2>
          <p className="text-xs text-brand-gray-light mt-3 leading-relaxed font-medium">
            Available as a web client or native application. Perfect for tablets, laptops, and mobile screens.
          </p>
        </div>

        {/* Stacked Parallax Devices Container */}
        <div className="relative h-[480px] w-full max-w-4xl mx-auto flex items-center justify-center">
          
          {/* Laptop Frame (MacBook Mock) - Background layer */}
          <motion.div
            style={{
              x: mousePos.x * 20,
              y: mousePos.y * 20,
            }}
            className="absolute z-10 w-[550px] h-[320px] border border-brand-gray bg-brand-gray-dark rounded shadow-2xl overflow-hidden hidden md:block"
          >
            {/* Screen topbar */}
            <div className="h-6 bg-brand-black border-b border-brand-gray flex items-center px-4 justify-between">
              <div className="flex gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-brand-gray/50" />
                <span className="w-2.5 h-2.5 rounded-full bg-brand-gray/50" />
                <span className="w-2.5 h-2.5 rounded-full bg-brand-gray/50" />
              </div>
              <span className="text-[8px] font-mono text-brand-gray-light">nosus.foo/vault</span>
              <div className="w-8" />
            </div>

            {/* Laptop Content mock dashboard layout */}
            <div className="p-5 grid grid-cols-12 gap-4 h-full">
              <div className="col-span-3 border-r border-brand-gray/50 flex flex-col gap-2 pr-2">
                <div className="w-full h-4 bg-brand-gray/30 rounded" />
                <div className="w-5/6 h-3 bg-brand-gray/20 rounded" />
                <div className="w-3/4 h-3 bg-brand-gray/20 rounded" />
              </div>
              <div className="col-span-9 flex flex-col gap-4">
                <div className="flex justify-between items-center border-b border-brand-gray/40 pb-2">
                  <span className="text-[10px] font-bold text-white uppercase tracking-wider">Secured Vault Files</span>
                  <div className="w-16 h-4 bg-white/10 rounded" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div className="border border-brand-gray p-3 rounded bg-brand-black flex flex-col gap-2">
                    <FileText className="h-5 w-5 text-white" />
                    <span className="text-[9px] font-mono text-white font-bold">sys_specs.pdf</span>
                  </div>
                  <div className="border border-brand-gray p-3 rounded bg-brand-black flex flex-col gap-2">
                    <Lock className="h-5 w-5 text-white" />
                    <span className="text-[9px] font-mono text-white font-bold">keys_metadata.csv</span>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Tablet Frame (iPad Mock) - Midground layer offset left */}
          <motion.div
            style={{
              x: mousePos.x * 40 - 150,
              y: mousePos.y * 40 + 50,
            }}
            className="absolute z-20 w-[280px] h-[380px] border-4 border-black bg-brand-gray-dark rounded-[16px] shadow-2xl overflow-hidden hidden sm:block"
          >
            {/* Tablet Topbar */}
            <div className="h-4 bg-brand-black flex items-center px-4 justify-between border-b border-brand-gray">
              <span className="w-1.5 h-1.5 rounded-full bg-brand-gray" />
            </div>

            {/* Tablet Mock content */}
            <div className="p-4 flex flex-col gap-4 h-full justify-between pb-8">
              <div className="flex justify-between items-center pb-2 border-b border-brand-gray/40">
                <span className="text-[9px] font-bold text-white uppercase tracking-wider">Study desk list</span>
                <span className="text-[8px] font-mono text-brand-gray-light">Active</span>
              </div>
              
              <div className="flex flex-col gap-2">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="flex justify-between items-center border border-brand-gray/60 p-2 rounded bg-brand-black">
                    <div className="flex items-center gap-2">
                      <FileText className="h-3.5 w-3.5 text-white" />
                      <span className="text-[8px] font-mono text-white">doc_{i + 1}.pdf</span>
                    </div>
                    <span className="w-2 h-2 rounded-full bg-green-400" />
                  </div>
                ))}
              </div>
            </div>
          </motion.div>

          {/* Phone Frame (iPhone Mock) - Foreground layer offset right */}
          <motion.div
            style={{
              x: mousePos.x * 60 + (showTablet ? 200 : 0),
              y: mousePos.y * 60 + (showTablet ? 80 : 0),
            }}
            className="absolute z-30 w-[170px] h-[320px] border-[6px] border-black bg-brand-gray-dark rounded-[24px] shadow-2xl overflow-hidden"
          >
            {/* Dynamic island mock */}
            <div className="absolute top-2 left-1/2 -translate-x-1/2 w-14 h-3 bg-black rounded-full z-40" />

            {/* Phone Mock content */}
            <div className="p-3 pt-8 flex flex-col gap-4 justify-between h-full pb-6">
              <div className="flex flex-col gap-1 items-center">
                <Shield className="h-6 w-6 text-white" />
                <span className="text-[9px] font-bold text-white uppercase tracking-widest mt-1">NO SUS app</span>
              </div>

              <div className="flex-1 flex flex-col justify-center items-center gap-2">
                <div className="w-24 h-24 rounded-full border border-dashed border-brand-gray flex items-center justify-center bg-brand-black">
                  <Eye className="h-5 w-5 text-brand-gray-light" />
                </div>
                <span className="text-[8px] font-mono text-brand-gray-light text-center leading-normal">
                  Hold screen to reveal blur
                </span>
              </div>

              <div className="h-7 bg-white text-black text-[8px] font-bold uppercase tracking-wider rounded flex items-center justify-center">
                Open Secure Desk
              </div>
            </div>
          </motion.div>

        </div>

      </div>
    </section>
  );
}
