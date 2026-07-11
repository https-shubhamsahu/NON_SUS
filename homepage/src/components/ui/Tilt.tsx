"use client";

import React, { useRef, useState } from "react";

interface TiltProps {
  children: React.ReactNode;
  className?: string;
  max?: number; // max tilt angle in degrees
  perspective?: number; // perspective in px
  scale?: number; // scale on hover
}

export default function Tilt({ children, className = "", max = 8, perspective = 1000, scale = 1.01 }: TiltProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [coords, setCoords] = useState({ x: 0, y: 0 });
  const [isHovered, setIsHovered] = useState(false);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!containerRef.current) return;
    const card = containerRef.current;
    const box = card.getBoundingClientRect();
    const x = e.clientX - box.left - box.width / 2;
    const y = e.clientY - box.top - box.height / 2;
    setCoords({ x: x / (box.width / 2), y: y / (box.height / 2) });
  };

  const handleMouseEnter = () => {
    setIsHovered(true);
  };

  const handleMouseLeave = () => {
    setIsHovered(false);
    setCoords({ x: 0, y: 0 });
  };

  const rotateX = -coords.y * max;
  const rotateY = coords.x * max;

  return (
    <div
      ref={containerRef}
      onMouseMove={handleMouseMove}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      className={`transition-all duration-300 ease-out ${className}`}
      style={{
        transform: isHovered
          ? `perspective(${perspective}px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(${scale}, ${scale}, ${scale})`
          : `perspective(${perspective}px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)`,
        transformStyle: "preserve-3d",
      }}
    >
      {children}
    </div>
  );
}
