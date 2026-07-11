"use client";

import React, { useState, useEffect, useMemo } from "react";

interface ParallaxStarsProps {
  speed?: number;
  className?: string;
}

// Helper to generate random box shadows for pixel stars within a 2000px boundary
const generateBoxShadows = (n: number) => {
  let value = `${Math.floor(Math.random() * 2000)}px ${Math.floor(Math.random() * 2000)}px #FFF`;
  for (let i = 2; i <= n; i++) {
    value += `, ${Math.floor(Math.random() * 2000)}px ${Math.floor(Math.random() * 2000)}px #FFF`;
  }
  return value;
};

export default function ParallaxStars({ speed = 1, className = "" }: ParallaxStarsProps) {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMounted(true);
  }, []);

  const shadows = useMemo(() => {
    if (!mounted) return { small: "", medium: "", big: "" };
    return {
      small: generateBoxShadows(180),
      medium: generateBoxShadows(60),
      big: generateBoxShadows(25),
    };
  }, [mounted]);

  if (!mounted) {
    return null;
  }

  return (
    <div className={`absolute inset-0 overflow-hidden pointer-events-none z-0 ${className}`}>
      <style>{`
        @keyframes animStarUp {
          from { transform: translateY(0px); }
          to { transform: translateY(-2000px); }
        }
        .animate-star-small {
          animation: animStarUp ${40 / speed}s linear infinite;
        }
        .animate-star-medium {
          animation: animStarUp ${80 / speed}s linear infinite;
        }
        .animate-star-big {
          animation: animStarUp ${120 / speed}s linear infinite;
        }
      `}</style>

      {/* Layer 1: Small Stars (1x1px) */}
      <div
        className="absolute left-0 top-0 w-[1px] h-[1px] bg-transparent opacity-30 animate-star-small"
        style={{ boxShadow: shadows.small }}
      >
        <div
          className="absolute top-[2000px] w-[1px] h-[1px] bg-transparent"
          style={{ boxShadow: shadows.small }}
        />
      </div>

      {/* Layer 2: Medium Stars (2x2px) */}
      <div
        className="absolute left-0 top-0 w-[2px] h-[2px] bg-transparent opacity-45 animate-star-medium"
        style={{ boxShadow: shadows.medium }}
      >
        <div
          className="absolute top-[2000px] w-[2px] h-[2px] bg-transparent"
          style={{ boxShadow: shadows.medium }}
        />
      </div>

      {/* Layer 3: Big Stars (3x3px) */}
      <div
        className="absolute left-0 top-0 w-[3px] h-[3px] bg-transparent opacity-60 animate-star-big"
        style={{ boxShadow: shadows.big }}
      >
        <div
          className="absolute top-[2000px] w-[3px] h-[3px] bg-transparent"
          style={{ boxShadow: shadows.big }}
        />
      </div>
    </div>
  );
}
