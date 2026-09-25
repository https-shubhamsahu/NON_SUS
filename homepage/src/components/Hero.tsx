import Link from "next/link";
import { ArrowRight } from "lucide-react";

import AppLink from "./AppLink";

// Finder squares + a fixed scatter of modules. Decorative only — never a
// scannable code (real pairing QRs are drawn by /go at runtime).
const QR_MODULES: [number, number][] = [
  [0, 3], [1, 4], [3, 0], [3, 2], [4, 3], [5, 5], [3, 5], [5, 3], [4, 6],
  [6, 4], [2, 3], [6, 6], [3, 7], [7, 3], [7, 6], [6, 7], [4, 1], [1, 7],
];

function FakeQr({ x, y, size, className }: { x: number; y: number; size: number; className?: string }) {
  const cell = size / 9;
  const finder = (fx: number, fy: number) => (
    <g key={`${fx}-${fy}`}>
      <rect x={fx + cell * 0.5} y={fy + cell * 0.5} width={cell * 2} height={cell * 2} fill="none" stroke="currentColor" strokeWidth={cell * 0.6} />
      <rect x={fx + cell} y={fy + cell} width={cell} height={cell} fill="currentColor" />
    </g>
  );
  return (
    <g className={className}>
      {finder(x, y)}
      {finder(x + cell * 6, y)}
      {finder(x, y + cell * 6)}
      {QR_MODULES.map(([cx, cy]) => (
        <rect key={`${cx}-${cy}`} x={x + cx * cell} y={y + cy * cell} width={cell * 0.9} height={cell * 0.9} fill="currentColor" />
      ))}
    </g>
  );
}

function SavedBubble({ y, x, w, name, meta, className }: { y: number; x: number; w: number; name: string; meta: string; className: string }) {
  return (
    <g className={className}>
      <rect x={x} y={y} width={w} height={24} rx={6} className="fill-muted stroke-border" strokeWidth={1} />
      <rect x={x + 7} y={y + 7} width={10} height={10} rx={2} fill="none" stroke="currentColor" strokeWidth={1} opacity={0.7} />
      <text x={x + 23} y={y + 15.5} className="pg-mono" fontSize={8} fill="currentColor" fontWeight={600}>
        {name}
      </text>
      <text x={x + w - 7} y={y + 15.5} className="pg-mono" fontSize={7} fill="currentColor" opacity={0.55} textAnchor="end">
        {meta}
      </text>
    </g>
  );
}

function PairingDemo() {
  return (
    <div
      className="pg paper-card overflow-hidden"
      role="img"
      aria-label="Animated demo: the computer shows a QR, the phone scans it, both show the same two-digit code, you approve on the phone, and the items you send appear on the computer."
    >
      <div className="flex items-center justify-between gap-3 border-b border-border px-4 py-3 font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
        <span className="flex min-w-0 items-center gap-2">
          <span className="eink-live text-foreground" />
          <span className="truncate">nosus.foo/go</span>
        </span>
        <span className="shrink-0">Pairing · illustration</span>
      </div>

      <svg viewBox="0 0 480 250" className="block h-auto w-full text-foreground" fill="none" aria-hidden="true">
        {/* Laptop */}
        <rect x="28" y="18" width="288" height="186" rx="10" className="stroke-border" strokeWidth="1.5" fill="currentColor" fillOpacity="0.03" />
        <rect x="40" y="30" width="264" height="160" rx="4" className="fill-background stroke-border" strokeWidth="1" />
        <path d="M16 204 H328 L344 222 H0 Z" className="fill-card stroke-border" strokeWidth="1.5" strokeLinejoin="round" />
        <rect x="146" y="207" width="52" height="9" rx="2" className="stroke-border" strokeWidth="1" />
        <text x="52" y="46" className="pg-mono" fontSize="8" fill="currentColor" opacity="0.55">nosus.foo/go</text>
        <line x1="40" y1="54" x2="304" y2="54" className="stroke-border" strokeWidth="1" />

        {/* Laptop · stage 1: QR waiting */}
        <g className="pg-s1">
          <FakeQr x={140} y={70} size={64} />
          <text x="172" y="162" className="pg-mono" fontSize="8" fill="currentColor" opacity="0.7" textAnchor="middle">Scan with the NO SUS app</text>
        </g>

        {/* Laptop · stage 2: match code */}
        <g className="pg-s2">
          <text x="172" y="84" className="pg-mono" fontSize="8" fill="currentColor" opacity="0.6" textAnchor="middle" letterSpacing="1.5">MATCH CODE</text>
          <text x="172" y="134" className="pg-mono" fontSize="44" fontWeight="800" fill="currentColor" textAnchor="middle" letterSpacing="6">42</text>
          <text x="172" y="160" className="pg-mono" fontSize="7.5" fill="currentColor" opacity="0.6" textAnchor="middle">Same digits on your phone? Approve there.</text>
        </g>

        {/* Laptop · stage 3: Saved chat */}
        <g className="pg-s3">
          <text x="52" y="72" fontSize="10" fontWeight="800" fill="currentColor">Saved</text>
          <text x="292" y="72" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.6" textAnchor="end">session ≤ 60:00</text>
        </g>
        <SavedBubble className="pg-b1" x={120} y={84} w={172} name="lecture-notes.pdf" meta="sent" />
        <SavedBubble className="pg-b2" x={96} y={114} w={196} name="internship-resume.docx" meta="sent" />
        <SavedBubble className="pg-b3" x={150} y={144} w={142} name="timetable.png" meta="sent" />

        {/* Link between devices */}
        <line x1="316" y1="130" x2="356" y2="130" stroke="currentColor" strokeOpacity="0.35" strokeWidth="1.5" strokeDasharray="3 4" />
        <rect className="pg-packet-a" x="348" y="127" width="6" height="6" rx="1" fill="currentColor" />
        <rect className="pg-packet-b" x="348" y="127" width="6" height="6" rx="1" fill="currentColor" />

        {/* Phone */}
        <rect x="356" y="30" width="108" height="206" rx="16" className="fill-card stroke-foreground" strokeWidth="1.5" />
        <rect x="364" y="46" width="92" height="176" rx="6" className="fill-background stroke-border" strokeWidth="1" />
        <rect x="398" y="36" width="24" height="4" rx="2" className="fill-border" />

        {/* Phone · stage 1: camera */}
        <g className="pg-s1">
          <text x="410" y="64" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.6" textAnchor="middle" letterSpacing="1">SCAN</text>
          <path d="M378 80 v-8 h8 M434 72 h8 v8 M442 128 v8 h-8 M386 136 h-8 v-8" stroke="currentColor" strokeWidth="1.5" />
          <FakeQr x={386} y={80} size={48} className="opacity-40" />
          <line className="pg-scan" x1="380" y1="76" x2="440" y2="76" stroke="currentColor" strokeWidth="1.5" />
          <text x="410" y="160" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.7" textAnchor="middle">Point at the screen</text>
        </g>

        {/* Phone · stage 2: approve */}
        <g className="pg-s2">
          <text x="410" y="66" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.6" textAnchor="middle" letterSpacing="1">MATCH CODE</text>
          <text x="410" y="100" className="pg-mono" fontSize="28" fontWeight="800" fill="currentColor" textAnchor="middle" letterSpacing="4">42</text>
          <g className="pg-press">
            <circle cx="410" cy="140" r="17" className="fill-card stroke-border" strokeWidth="1" />
            <path d="M404 137 c0-7 12-7 12 0 M401 141 c0-12 18-12 18 0 M406 145 c0 4 8 4 8 0 M410 137 v6" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
          </g>
          <rect x="376" y="178" width="68" height="20" rx="4" className="fill-foreground" />
          <text x="410" y="191" className="pg-mono fill-background" fontSize="7.5" fontWeight="700" textAnchor="middle" letterSpacing="1">APPROVE</text>
        </g>

        {/* Phone · stage 3: connected */}
        <g className="pg-s3">
          <circle cx="386" cy="63" r="2.5" fill="currentColor" />
          <text x="393" y="66" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.8" letterSpacing="0.5">CONNECTED</text>
          <circle cx="410" cy="106" r="18" stroke="currentColor" strokeWidth="1.5" />
          <path d="M402 106 l6 6 l11 -12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          <text x="410" y="146" className="pg-mono" fontSize="7" fill="currentColor" opacity="0.7" textAnchor="middle">Sending 3 items</text>
          <rect x="384" y="178" width="52" height="20" rx="4" className="stroke-foreground" strokeWidth="1" />
          <text x="410" y="191" className="pg-mono" fontSize="7.5" fontWeight="700" fill="currentColor" textAnchor="middle" letterSpacing="1">END</text>
        </g>
      </svg>

      <ol className="grid grid-cols-3 border-t border-border font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
        <li className="pg-l1 px-3 py-3 sm:px-4">01 Scan</li>
        <li className="pg-l2 border-l border-border px-3 py-3 sm:px-4">02 Match</li>
        <li className="pg-l3 border-l border-border px-3 py-3 sm:px-4">03 Live</li>
      </ol>
    </div>
  );
}

// Every item here must stay true of what ships (AGENTS.md §0.3).
const SPEC_STRIP = [
  "P-256 key agreement",
  "AES-256-GCM session",
  "No Google token on the borrowed PC",
  "Nothing to install on the borrowed PC",
  "Burn keys live in the #fragment",
  "Open-source client",
  "Android app + web app",
  "No ad trackers",
];

const FACTS = [
  { label: "No login", text: "Google never signs in on that computer." },
  { label: "≤ 60 min", text: "Then the session ends on its own." },
  { label: "You approve", text: "Fingerprint or face unlock on your phone." },
];

export default function Hero() {
  return (
    <section id="top" className="relative overflow-hidden border-b border-border bg-background">
      <div className="hero-glow pointer-events-none absolute inset-0" aria-hidden="true" />
      <div className="swiss-grid pointer-events-none absolute inset-0 [mask-image:linear-gradient(to_bottom,#000_40%,transparent)]" aria-hidden="true" />

      <div className="relative mx-auto w-full max-w-7xl px-6 pt-28 pb-16 md:px-8 md:pt-36 md:pb-24">
        <div className="grid grid-cols-1 items-center gap-12 lg:grid-cols-12 lg:gap-16">
          <div className="flex flex-col gap-6 lg:col-span-6">
            <div className="rise flex flex-wrap items-center gap-2">
              <span className="tech-badge">
                <span className="eink-live text-foreground" />
                NO SUS Go · early access
              </span>
              <span className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground">
                Android + web
              </span>
            </div>

            <h1 className="text-[44px] font-black leading-[0.98] tracking-[-0.035em] text-foreground sm:text-6xl xl:text-[76px]">
              Your Drive on
              <br />
              any screen.
            </h1>

            <p className="rise max-w-xl text-lg leading-relaxed text-foreground sm:text-xl" style={{ animationDelay: "60ms" }}>
              Open your files on a cyber-cafe, college-lab or print-shop computer
              — without signing Google in there.
            </p>

            <p className="rise max-w-xl text-base leading-relaxed text-muted-foreground" style={{ animationDelay: "120ms" }}>
              Scan a QR with the NO SUS phone app, match a two-digit code, and
              approve. The computer gets only the items you send, for at most 60
              minutes. It never gets your Google password or token.
            </p>

            <div className="rise flex flex-col gap-3 sm:flex-row sm:flex-wrap" style={{ animationDelay: "180ms" }}>
              <Link href="/go" className="btn btn-primary group min-h-12 w-full whitespace-nowrap px-6 sm:w-auto">
                Open on this computer
                <ArrowRight className="nudge h-4 w-4" aria-hidden="true" />
              </Link>
              <AppLink className="btn btn-ghost min-h-12 w-full whitespace-nowrap px-6 sm:w-auto">
                Get the Android app
              </AppLink>
            </div>

            <p className="rise text-sm leading-relaxed text-muted-foreground" style={{ animationDelay: "220ms" }}>
              Go is in early access. It shows up in the app once it&apos;s enabled
              for your account.
            </p>

            <dl className="rise mt-2 grid grid-cols-1 gap-4 border-t border-border pt-6 sm:grid-cols-3" style={{ animationDelay: "260ms" }}>
              {FACTS.map((f) => (
                <div key={f.label} className="flex flex-col gap-1">
                  <dt className="font-mono text-xs font-bold uppercase tracking-widest text-foreground">
                    {f.label}
                  </dt>
                  <dd className="text-sm leading-snug text-muted-foreground">{f.text}</dd>
                </div>
              ))}
            </dl>
          </div>

          <div className="rise lg:col-span-6" style={{ animationDelay: "120ms" }}>
            <PairingDemo />
          </div>
        </div>
      </div>

      {/* Spec strip */}
      <div className="marquee relative overflow-hidden border-t border-border bg-card/60 py-3">
        <div className="marquee-track">
          {[0, 1].map((copy) => (
            <ul key={copy} className="flex shrink-0 items-center" aria-hidden={copy === 1 ? true : undefined}>
              {SPEC_STRIP.map((item) => (
                <li key={item} className="flex items-center gap-6 pr-6 font-mono text-xs uppercase tracking-widest text-muted-foreground whitespace-nowrap">
                  <span>{item}</span>
                  <span className="h-1 w-1 bg-foreground/50" aria-hidden="true" />
                </li>
              ))}
            </ul>
          ))}
        </div>
      </div>
    </section>
  );
}
