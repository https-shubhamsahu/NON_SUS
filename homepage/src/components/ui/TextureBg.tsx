"use client";

import { useEffect, useRef } from "react";

export default function TextureBg() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Fixed small canvas to generate noise pattern once and tile it
    canvas.width = 256;
    canvas.height = 256;

    const imgData = ctx.createImageData(canvas.width, canvas.height);
    const data = imgData.data;

    // Create subtle tactile noise and organic paper speckles
    for (let i = 0; i < data.length; i += 4) {
      // Base noise
      const noise = Math.random() * 15;
      
      // Rare organic dark fiber speckles (paper effect)
      const isSpeckle = Math.random() < 0.0005;
      const val = isSpeckle ? 30 : 255 - noise;

      data[i] = val;     // R
      data[i + 1] = val; // G
      data[i + 2] = val; // B
      // Low opacity to blend with background
      data[i + 3] = isSpeckle ? 45 : 12;
    }

    ctx.putImageData(imgData, 0, 0);
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none fixed inset-0 z-40 h-full w-full opacity-[0.45]"
      style={{
        mixBlendMode: "overlay",
      }}
    />
  );
}
