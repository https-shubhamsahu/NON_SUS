"use client";

import { motion } from "framer-motion";
import BurnTool from "./BurnTool";
import Tilt from "./ui/Tilt";
import LightRays from "./ui/LightRays";
import ParallaxStars from "./ui/ParallaxStars";

export default function Hero() {
  return (
    <section className="relative min-h-screen flex flex-col justify-center items-center pt-32 pb-20 overflow-hidden swiss-grid">
      <LightRays
        raysOrigin="top-center"
        raysColor="#ffffff"
        raysSpeed={0.8}
        lightSpread={1.2}
        rayLength={1.8}
        followMouse={true}
        mouseInfluence={0.15}
        noiseAmount={0.01}
        distortion={0.04}
      />
      <ParallaxStars speed={0.4} />
      {/* Fades the light-ray glow into the next section's flat black instead
          of cutting off hard at the section boundary. */}
      <div className="absolute inset-x-0 bottom-0 z-[1] h-56 md:h-72 bg-gradient-to-b from-transparent to-brand-black pointer-events-none" />
      <div className="relative z-10 w-full max-w-7xl px-6 md:px-8 flex flex-col items-center justify-center">
        {/* 1. Header (Centered Headline & Subtitle) */}
        <div className="flex flex-col items-center text-center max-w-4xl gap-6">
          <motion.span
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase"
          >
            Document Leak Attribution
          </motion.span>

          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.1 }}
            className="text-4xl sm:text-5xl md:text-6xl font-black tracking-tighter uppercase leading-[0.95] text-white select-none"
          >
            If It Leaks<span className="text-brand-gray-light">,</span> <br />
            <span className="text-brand-gray-light">You&apos;ll Know Exactly Who</span><span className="text-white">.</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.2 }}
            className="text-sm sm:text-base md:text-lg text-brand-gray-light font-medium leading-relaxed max-w-2xl"
          >
            Every document you share is watermarked to whoever opens it<span className="text-white">.</span> Every note you burn
            disappears before anyone else can<span className="text-white">.</span> Try it right here; no account needed<span className="text-white">.</span>
          </motion.p>
        </div>

        {/* 2. Center: Interactive Tool (BurnTool) wrapped in Tilt */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.3 }}
          className="w-full max-w-2xl mt-12 relative z-10"
        >
          <Tilt max={6} scale={1.01}>
            <BurnTool />
          </Tilt>
        </motion.div>


      </div>
    </section>
  );
}
