"use client";

import { useEffect, useRef } from "react";

/** Draws a QR code in-browser. The payload never leaves the device. */
export default function ShareQr({
  value,
  size = 112,
}: {
  value: string;
  size?: number;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    let cancelled = false;
    if (!value) return;

    (async () => {
      try {
        const QRCode = (await import("qrcode")).default;
        if (cancelled || !canvasRef.current) return;
        await QRCode.toCanvas(canvasRef.current, value, {
          width: size,
          margin: 1,
          errorCorrectionLevel: "M",
          color: { dark: "#000000", light: "#ffffff" },
        });
      } catch {
        // Leave a blank canvas; the copy-link button still works.
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [value, size]);

  return (
    <canvas
      ref={canvasRef}
      width={size}
      height={size}
      className="rounded-md bg-white"
      aria-label="QR code for the share link"
    />
  );
}
