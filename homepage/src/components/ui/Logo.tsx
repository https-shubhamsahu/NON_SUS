"use client";

import React from "react";

interface LogoProps {
  className?: string;
  sizeClass?: string; // e.g. "text-xl" or "text-2xl"
}

export default function NoSusLogo({ className = "", sizeClass = "text-xl" }: LogoProps) {
  return (
    <span className={`font-sans font-black tracking-tighter text-white inline-flex items-baseline select-none whitespace-nowrap ${sizeClass} ${className}`}>
      NO SUS
      <span 
        className="inline-block bg-[#808080] ml-[0.08em] align-baseline"
        style={{
          width: "0.21em",
          height: "0.21em",
          marginBottom: "0.02em"
        }}
      />
    </span>
  );
}
