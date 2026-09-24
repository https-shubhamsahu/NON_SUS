import Link from "next/link";

import AppLink from "./AppLink";

function DevicesIllustration() {
  return (
    <div
      className="hero-devices relative mx-auto w-full max-w-md lg:max-w-none"
      aria-hidden="true"
    >
      <svg
        viewBox="0 0 420 280"
        className="h-auto w-full text-foreground"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        role="presentation"
      >
        {/* Laptop body */}
        <rect
          x="48"
          y="48"
          width="260"
          height="168"
          rx="6"
          className="stroke-border"
          strokeWidth="2"
          fill="currentColor"
          fillOpacity="0.04"
        />
        <rect
          x="64"
          y="64"
          width="228"
          height="128"
          className="fill-muted stroke-border"
          strokeWidth="1"
        />
        {/* Laptop base */}
        <path
          d="M28 216 H328 L348 236 H8 Z"
          className="fill-muted stroke-border"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />

        {/* Decorative QR-like mark on laptop screen */}
        <g className="stroke-foreground" strokeWidth="2.5" fill="none">
          <rect x="118" y="92" width="28" height="28" />
          <rect x="126" y="100" width="12" height="12" fill="currentColor" stroke="none" />
          <rect x="198" y="92" width="28" height="28" />
          <rect x="206" y="100" width="12" height="12" fill="currentColor" stroke="none" />
          <rect x="118" y="160" width="28" height="28" />
          <rect x="126" y="168" width="12" height="12" fill="currentColor" stroke="none" />
          {/* Center modules */}
          <rect x="158" y="100" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="176" y="100" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="158" y="118" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="194" y="118" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="176" y="136" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="158" y="154" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="194" y="154" width="10" height="10" fill="currentColor" stroke="none" />
          <rect x="212" y="136" width="10" height="10" fill="currentColor" stroke="none" />
        </g>

        {/* Scan line over QR (CSS-animated via clip) */}
        <clipPath id="hero-screen-clip">
          <rect x="64" y="64" width="228" height="128" />
        </clipPath>
        <g clipPath="url(#hero-screen-clip)">
          <line
            className="hero-scan-line"
            x1="64"
            y1="64"
            x2="292"
            y2="64"
            stroke="currentColor"
            strokeOpacity="0.45"
            strokeWidth="2"
          />
        </g>

        {/* Phone */}
        <rect
          x="300"
          y="88"
          width="88"
          height="152"
          rx="12"
          className="fill-card stroke-border"
          strokeWidth="2"
        />
        <rect
          x="312"
          y="108"
          width="64"
          height="100"
          className="fill-muted stroke-border"
          strokeWidth="1"
        />
        {/* Phone notch */}
        <rect
          x="328"
          y="96"
          width="32"
          height="6"
          rx="3"
          className="fill-border"
        />
        {/* Phone home indicator */}
        <rect
          x="328"
          y="220"
          width="32"
          height="4"
          rx="2"
          className="fill-border"
        />

        {/* Dashed link phone ↔ laptop */}
        <path
          className="hero-dash-link stroke-muted-foreground"
          d="M288 150 C294 150, 296 150, 300 150"
          strokeWidth="1.5"
          strokeDasharray="4 4"
          fill="none"
        />
      </svg>
    </div>
  );
}

export default function Hero() {
  return (
    <section
      id="top"
      className="relative overflow-hidden bg-background swiss-grid pt-28 pb-16 md:pt-32 md:pb-24"
    >
      <style>{`
        @keyframes hero-scan {
          0% { transform: translateY(0); }
          100% { transform: translateY(128px); }
        }
        @keyframes hero-dash {
          to { stroke-dashoffset: -16; }
        }
        .hero-scan-line {
          animation: hero-scan 2.4s ease-in-out infinite alternate;
          transform-box: fill-box;
          transform-origin: top;
        }
        .hero-dash-link {
          animation: hero-dash 1.2s linear infinite;
        }
        @media (prefers-reduced-motion: reduce) {
          .hero-scan-line,
          .hero-dash-link {
            animation: none;
          }
        }
      `}</style>

      <div className="relative z-10 mx-auto w-full max-w-7xl px-6 md:px-8">
        <div className="flex flex-col gap-12 lg:flex-row lg:items-center lg:gap-16 lg:justify-between">
          {/* Copy */}
          <div className="flex w-full max-w-xl flex-col gap-6 lg:shrink-0">
            <p className="text-xs font-bold uppercase tracking-widest text-muted-foreground">
              Your NO SUS Address
            </p>

            <h1 className="text-4xl font-black tracking-tight text-foreground sm:text-5xl md:text-6xl leading-[1.05]">
              Your Drive on any screen.
            </h1>

            <p className="text-xl font-medium leading-snug text-foreground">
              Share your address, not your number.
            </p>

            <p className="text-base leading-relaxed text-muted-foreground max-w-lg">
              Open Saved on a borrowed computer — cyber cafe, college lab, print
              shop — by scanning a QR with the NO SUS phone app. The computer
              never gets your Google password or Google token. The phone sends
              only what you approve.
            </p>

            <div className="flex w-full flex-col gap-3 sm:flex-row sm:flex-wrap">
              <Link
                href="/go"
                className="btn btn-primary min-h-11 w-full sm:w-auto"
              >
                Open on this computer
              </Link>
              <AppLink className="btn btn-ghost min-h-11 w-full sm:w-auto">
                Get the Android app
              </AppLink>
            </div>
          </div>

          {/* Illustration — below copy on mobile, right column on desktop */}
          <div className="w-full lg:flex-1 lg:max-w-lg">
            <DevicesIllustration />
          </div>
        </div>
      </div>
    </section>
  );
}
