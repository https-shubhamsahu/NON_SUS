import Link from "next/link";
import { ArrowRight, Flame, FileUp, Link2, Key } from "lucide-react";

import BurnTool from "./BurnTool";

// Keep in step with burnApi.ts (NOTE/FILE caps, pairing-code key window).
const BURN_FACTS = [
  {
    icon: Flame,
    title: "Burn Notes",
    text: "Opens once, then the row is deleted. Unread notes expire in 1 hour, 24 hours or 7 days.",
  },
  {
    icon: FileUp,
    title: "Burn Files",
    text: "One file up to 25 MB here (up to 10 in the app), wiped within minutes of being claimed.",
  },
  {
    icon: Link2,
    title: "The key rides in the link",
    text: "A normal link keeps the key after the # — browsers never send that part to a server.",
  },
  {
    icon: Key,
    title: "Optional two-digit code",
    text: "For a single note or file, the key waits on the server for up to 20 minutes, then is deleted.",
  },
];

// Every item here must stay true of what ships (AGENTS.md §0.3).
const SPEC_STRIP = [
  "AES-256 in your browser",
  "Keys in the #fragment by default",
  "Opens once, then burns",
  "No account on either side",
  "No Google token on a borrowed PC",
  "Open-source client",
  "Android app + web app",
  "No ad trackers",
];

export default function Hero() {
  return (
    <section id="try" className="relative overflow-hidden border-b border-border bg-background">
      <div className="hero-glow pointer-events-none absolute inset-0" aria-hidden="true" />
      <div className="swiss-grid pointer-events-none absolute inset-0 [mask-image:linear-gradient(to_bottom,#000_40%,transparent)]" aria-hidden="true" />

      <div className="relative mx-auto w-full max-w-7xl px-6 pt-28 pb-16 md:px-8 md:pt-36 md:pb-24">
        {/* Phones read copy → tool → facts; xl puts the tool in its own column. */}
        <div className="grid grid-cols-1 items-center gap-x-10 gap-y-10 xl:grid-cols-12 xl:grid-rows-[auto_auto]">
          <div className="flex flex-col gap-6 xl:col-span-5 xl:row-start-1 xl:self-end">
            <div className="rise flex flex-wrap items-center gap-2">
              <span className="tech-badge">
                <span className="eink-live text-foreground" />
                No account · encrypted in your browser
              </span>
            </div>

            <h1 className="max-w-2xl text-[44px] font-black leading-[0.98] tracking-[-0.035em] text-foreground sm:text-6xl xl:text-[60px]">
              Send something that burns after reading.
            </h1>

            <p className="rise max-w-xl text-lg leading-relaxed text-muted-foreground sm:text-xl" style={{ animationDelay: "60ms" }}>
              Encrypted in this browser before it leaves. Nobody needs an
              account — not you, not the person you send it to.
            </p>
          </div>

          {/* The working tool is in the initial HTML — never gated on an animation. */}
          <div className="flex justify-center py-2 sm:py-6 xl:col-span-7 xl:col-start-6 xl:row-span-2 xl:row-start-1 xl:justify-end xl:py-6">
            <BurnTool />
          </div>

          <div className="flex flex-col gap-6 xl:col-span-5 xl:row-start-2 xl:self-start">

            <ul className="rise grid grid-cols-1 gap-x-8 gap-y-5 border-t border-border pt-6 sm:grid-cols-2" style={{ animationDelay: "120ms" }}>
              {BURN_FACTS.map((f) => (
                <li key={f.title} className="flex gap-3">
                  <f.icon className="mt-0.5 h-5 w-5 shrink-0 text-foreground" strokeWidth={1.5} aria-hidden />
                  <div>
                    <h2 className="text-sm font-bold text-foreground">{f.title}</h2>
                    <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{f.text}</p>
                  </div>
                </li>
              ))}
            </ul>

            <Link
              href="/#doors"
              className="rise group inline-flex min-h-11 w-fit items-center gap-2 text-sm font-bold uppercase tracking-wider text-foreground hover:text-muted-foreground"
              style={{ animationDelay: "180ms" }}
            >
              Borrowing a computer? Open your Drive there
              <ArrowRight className="nudge h-4 w-4" aria-hidden="true" />
            </Link>
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
