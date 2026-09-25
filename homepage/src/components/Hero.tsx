import Link from "next/link";

import AppLink from "./AppLink";

function DevicesIllustration() {
  return (
    <div
      className="hero-devices relative mx-auto w-full max-w-md lg:max-w-none paper-card p-4 sm:p-6 bg-card/80 backdrop-blur-sm border border-border rounded-[16px] shadow-sm overflow-hidden"
      aria-hidden="true"
    >
      {/* Top terminal titlebar for illustration */}
      <div className="flex items-center justify-between pb-3 mb-2 border-b border-border/80 font-mono text-[10px] uppercase tracking-wider text-muted-foreground">
        <div className="flex items-center gap-2">
          <span className="eink-live text-foreground" />
          <span>PAIRING PROTOCOL // P-256</span>
        </div>
        <span className="text-foreground font-semibold">[ MATCH CODE: 42 ]</span>
      </div>

      <svg
        viewBox="0 0 420 270"
        className="h-auto w-full text-foreground"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        role="presentation"
      >
        {/* Technical background grid dots */}
        <g opacity="0.12" fill="currentColor">
          <circle cx="20" cy="20" r="1" />
          <circle cx="80" cy="20" r="1" />
          <circle cx="140" cy="20" r="1" />
          <circle cx="200" cy="20" r="1" />
          <circle cx="260" cy="20" r="1" />
          <circle cx="320" cy="20" r="1" />
          <circle cx="380" cy="20" r="1" />
          <circle cx="20" cy="80" r="1" />
          <circle cx="380" cy="80" r="1" />
          <circle cx="20" cy="140" r="1" />
          <circle cx="380" cy="140" r="1" />
          <circle cx="20" cy="200" r="1" />
          <circle cx="380" cy="200" r="1" />
        </g>

        {/* Laptop body */}
        <rect
          x="36"
          y="36"
          width="250"
          height="160"
          rx="8"
          className="stroke-border"
          strokeWidth="1.5"
          fill="currentColor"
          fillOpacity="0.03"
        />
        <rect
          x="48"
          y="48"
          width="226"
          height="126"
          rx="4"
          className="fill-muted/60 stroke-border"
          strokeWidth="1"
        />

        {/* Laptop base */}
        <path
          d="M20 196 H302 L318 214 H4 Z"
          className="fill-card stroke-border"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />
        {/* Trackpad */}
        <rect
          x="136"
          y="198"
          width="50"
          height="12"
          rx="2"
          className="stroke-border fill-muted/30"
          strokeWidth="1"
        />

        {/* Corner alignment crosshairs on laptop screen */}
        <path d="M56 56 H64 M56 56 V64" stroke="currentColor" strokeWidth="1" opacity="0.4" />
        <path d="M266 56 H258 M266 56 V64" stroke="currentColor" strokeWidth="1" opacity="0.4" />
        <path d="M56 166 H64 M56 166 V158" stroke="currentColor" strokeWidth="1" opacity="0.4" />
        <path d="M266 166 H258 M266 166 V158" stroke="currentColor" strokeWidth="1" opacity="0.4" />

        {/* Laptop screen header text */}
        <text x="60" y="68" fill="currentColor" opacity="0.5" fontSize="7" fontFamily="monospace" fontWeight="bold">
          TERMINAL: NOSUS.FOO/GO
        </text>
        <text x="210" y="68" fill="currentColor" opacity="0.8" fontSize="7" fontFamily="monospace" fontWeight="bold">
          [ 15:00 ]
        </text>

        {/* QR code matrix on laptop screen */}
        <g className="stroke-foreground" strokeWidth="2.5" fill="none">
          <rect x="108" y="80" width="28" height="28" />
          <rect x="116" y="88" width="12" height="12" fill="currentColor" stroke="none" />
          <rect x="186" y="80" width="28" height="28" />
          <rect x="194" y="88" width="12" height="12" fill="currentColor" stroke="none" />
          <rect x="108" y="132" width="28" height="28" />
          <rect x="116" y="140" width="12" height="12" fill="currentColor" stroke="none" />
          
          {/* Data blocks */}
          <rect x="146" y="88" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="162" y="88" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="146" y="104" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="178" y="104" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="162" y="120" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="146" y="136" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="178" y="136" width="8" height="8" fill="currentColor" stroke="none" />
          <rect x="194" y="120" width="8" height="8" fill="currentColor" stroke="none" />
        </g>

        {/* Scan line over QR */}
        <clipPath id="hero-screen-clip">
          <rect x="48" y="48" width="226" height="126" />
        </clipPath>
        <g clipPath="url(#hero-screen-clip)">
          <line
            className="hero-scan-line"
            x1="48"
            y1="76"
            x2="274"
            y2="76"
            stroke="currentColor"
            strokeOpacity="0.75"
            strokeWidth="2"
          />
        </g>

        {/* Phone Body */}
        <rect
          x="288"
          y="72"
          width="96"
          height="158"
          rx="14"
          className="fill-card stroke-foreground"
          strokeWidth="1.5"
        />
        <rect
          x="298"
          y="90"
          width="76"
          height="122"
          rx="4"
          className="fill-muted/70 stroke-border"
          strokeWidth="1"
        />

        {/* Phone screen elements */}
        <text x="304" y="104" fill="currentColor" opacity="0.6" fontSize="6.5" fontFamily="monospace" fontWeight="bold">
          SAVED CHAT
        </text>
        <circle cx="364" cy="102" r="2" fill="currentColor" className="eink-live" />

        {/* Phone Biometric Fingerprint / Key Icon in Center */}
        <circle cx="336" cy="136" r="16" className="stroke-border fill-card" strokeWidth="1" />
        <path
          d="M331 133 C331 129, 341 129, 341 133 M328 136 C328 127, 344 127, 344 136 M333 140 C333 143, 339 143, 339 140"
          className="stroke-foreground"
          strokeWidth="1.2"
          strokeLinecap="round"
          fill="none"
        />
        
        {/* Approve badge button on phone */}
        <rect
          x="306"
          y="168"
          width="60"
          height="18"
          rx="3"
          className="fill-foreground stroke-foreground"
          strokeWidth="1"
        />
        <text x="314" y="180" fill="var(--background)" fontSize="7" fontFamily="monospace" fontWeight="bold">
          APPROVE [42]
        </text>

        {/* Phone speaker notch & home bar */}
        <rect x="326" y="80" width="20" height="3" rx="1.5" className="fill-border" />
        <rect x="324" y="220" width="24" height="3" rx="1.5" className="fill-border" />

        {/* Data link between phone and laptop */}
        <path
          className="hero-dash-link stroke-foreground"
          d="M274 138 C280 138, 282 138, 288 138"
          strokeWidth="1.5"
          strokeDasharray="3 3"
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
      className="relative overflow-hidden bg-background swiss-grid pt-28 pb-16 md:pt-32 md:pb-24 border-b border-border"
    >
      <style>{`
        @keyframes hero-scan {
          0% { transform: translateY(0); }
          100% { transform: translateY(88px); }
        }
        @keyframes hero-pulse {
          0%, 100% { opacity: 0.35; }
          50% { opacity: 1; }
        }
        .hero-scan-line {
          animation: hero-scan 2.6s ease-in-out infinite alternate;
          transform-box: fill-box;
          transform-origin: top;
        }
        .hero-dash-link {
          animation: hero-pulse 1.8s ease-in-out infinite;
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
            {/* E-ink Technical Status Pill */}
            <div className="flex flex-wrap items-center gap-2">
              <span className="tech-badge">
                <span className="eink-live text-foreground" />
                <span>NO SUS PROTOCOL // v1.4.1</span>
              </span>
              <span className="font-mono text-[11px] text-muted-foreground uppercase tracking-widest border border-border px-2.5 py-1 rounded-[4px] bg-card">
                P-256 · CLIENT-ENCRYPTED
              </span>
            </div>

            <h1 className="text-4xl font-black tracking-tight text-foreground sm:text-5xl md:text-6xl leading-[1.05]">
              Your Drive on any screen.
            </h1>

            <p className="text-xl font-bold tracking-tight text-foreground sm:text-2xl">
              Share your address, not your number.
            </p>

            <p className="text-base leading-relaxed text-muted-foreground max-w-lg font-normal">
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

            {/* Micro spec ticker */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 border-t border-border/80 pt-6 mt-2 font-mono text-xs text-muted-foreground">
              <div className="flex flex-col gap-0.5">
                <span className="text-foreground font-bold tracking-wider">[ 0% LOGINS ]</span>
                <span className="text-[11px]">No credentials on PC</span>
              </div>
              <div className="flex flex-col gap-0.5">
                <span className="text-foreground font-bold tracking-wider">[ 60 MIN CAP ]</span>
                <span className="text-[11px]">Hard session timeout</span>
              </div>
              <div className="flex flex-col gap-0.5 col-span-2 sm:col-span-1">
                <span className="text-foreground font-bold tracking-wider">[ TOUCH PASS ]</span>
                <span className="text-[11px]">Fingerprint / Face ID</span>
              </div>
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
