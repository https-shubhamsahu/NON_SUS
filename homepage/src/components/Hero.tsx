import Link from "next/link";
import { ArrowRight, Flame, Stamp, MonitorSmartphone, Inbox, Users } from "lucide-react";

import BurnTool from "./BurnTool";

// Every feature gets the same row. Status must match what ships (AGENTS.md
// §0.3): Go is flag-gated early access; Drop and Group drops are not public.
const FEATURES = [
  {
    icon: Flame,
    name: "Burn Notes & Files",
    text: "Encrypted in your browser, opened once, then gone.",
    status: "Try it here",
    href: "/#try",
  },
  {
    icon: Stamp,
    name: "SecureSend",
    text: "Documents watermarked to whoever opens them. Revoke any time.",
    status: "In the app",
    href: "/#sharing",
  },
  {
    icon: MonitorSmartphone,
    name: "Go",
    text: "Your Drive on a borrowed computer, without signing Google in.",
    status: "Early access",
    href: "/#how-it-works",
  },
  {
    icon: Inbox,
    name: "Drop",
    text: "People send files to your address, not your number.",
    status: "Coming soon",
    href: "/#doors",
  },
  {
    icon: Users,
    name: "Group drops",
    text: "Each member's copy lands in their own Drive.",
    status: "Coming soon",
    href: "/#doors",
  },
];

// Every item here must stay true of what ships (AGENTS.md §0.3).
const SPEC_STRIP = [
  "AES-256 in your browser",
  "Opens once, then burns",
  "No account on either side",
  "Watermarked to the viewer",
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
        {/* Phones read copy → tool → features; xl puts the tool in its own column. */}
        <div className="grid grid-cols-1 items-center gap-x-10 gap-y-10 xl:grid-cols-12 xl:grid-rows-[auto_auto]">
          <div className="flex flex-col gap-6 xl:col-span-5 xl:row-start-1 xl:self-end">
            <div className="rise flex flex-wrap items-center gap-2">
              <span className="tech-badge">
                <span className="eink-live text-foreground" />
                Private sharing · Android + web
              </span>
            </div>

            <h1 className="max-w-2xl text-[44px] font-black leading-[0.98] tracking-[-0.035em] text-foreground sm:text-6xl xl:text-[60px]">
              Burn it. Trace it. Open it anywhere.
            </h1>

            <p className="rise max-w-xl text-lg leading-relaxed text-muted-foreground sm:text-xl" style={{ animationDelay: "60ms" }}>
              Self-destructing notes and files, documents watermarked to
              whoever opens them, and your Drive on a borrowed computer. Try
              the burn tool right here — no account.
            </p>
          </div>

          {/* The working tool is in the initial HTML — never gated on an animation. */}
          <div className="flex flex-col items-center gap-5 py-2 sm:py-6 xl:col-span-7 xl:col-start-6 xl:row-span-2 xl:row-start-1 xl:items-end xl:py-6">
            <BurnTool />
            <p className="max-w-[480px] text-center text-xs leading-relaxed text-muted-foreground xl:max-w-[520px]">
              Each note or file also gets a two-digit code; while it is valid
              (20 minutes by default) its key is held on our server too.
            </p>
          </div>

          <nav aria-label="Features" className="rise xl:col-span-5 xl:row-start-2 xl:self-start" style={{ animationDelay: "120ms" }}>
            <ul className="flex flex-col border-t border-border">
              {FEATURES.map((f) => (
                <li key={f.name} className="border-b border-border">
                  <Link href={f.href} className="group flex items-start gap-3 py-3.5 hover:bg-card/60">
                    <f.icon className="mt-0.5 h-5 w-5 shrink-0 text-foreground" strokeWidth={1.5} aria-hidden />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="flex flex-wrap items-center gap-x-3 gap-y-1">
                        <span className="text-sm font-bold text-foreground">{f.name}</span>
                        <span className="rounded-pill border border-border px-2 py-0.5 font-mono text-[11px] uppercase tracking-wider text-muted-foreground">
                          {f.status}
                        </span>
                      </span>
                      <span className="mt-1 text-sm leading-relaxed text-muted-foreground">{f.text}</span>
                    </span>
                    <ArrowRight className="nudge mt-1 h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
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
