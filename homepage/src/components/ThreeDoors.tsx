import Link from "next/link";
import { ArrowRight, DoorOpen, Inbox, Users } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

const goLimits = [
  "Anything you download or print may stay on that computer.",
  "Only approve a code on a screen in front of you.",
];

const upcoming = [
  {
    icon: Inbox,
    door: "Door 02",
    title: "Drop",
    text: "People will send you files at yourname.nosus.foo without your phone number. The door stays closed by default — you preview and accept before anything reaches your Drive.",
  },
  {
    icon: Users,
    door: "Door 03",
    title: "Group drops",
    text: "A planned group feed where each member's copy is saved to their own Drive, end-to-end encrypted. Watermarks that show who leaked a file come later.",
  },
];

export default function ThreeDoors() {
  return (
    <section id="doors" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto w-full max-w-7xl px-6 md:px-8">
        <SectionHeader
          index="02"
          eyebrow="NO SUS Address"
          title="One address. Three doors."
          lede="Share your address, not your number. Each door opens onto your own Google Drive — and only when you say so."
        />

        <div className="mt-12 grid grid-cols-1 gap-6 md:mt-16 lg:grid-cols-12">
          {/* Door 01 — Go (the one that works today, when enabled) */}
          <article className="paper-card paper-card-interactive flex flex-col gap-6 p-6 md:p-10 lg:col-span-7 lg:row-span-2">
            <div className="flex items-start justify-between gap-4">
              <div className="flex h-12 w-12 items-center justify-center rounded-[10px] border border-border bg-muted">
                <DoorOpen className="h-5 w-5 text-foreground" strokeWidth={1.5} aria-hidden />
              </div>
              <div className="flex flex-col items-end gap-2">
                <span className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground">Door 01</span>
                <span className="inline-flex items-center gap-1.5 rounded-pill border border-border bg-muted px-3 py-1 text-xs font-semibold uppercase tracking-wider text-foreground">
                  <span className="eink-live text-foreground" />
                  In app when enabled
                </span>
              </div>
            </div>

            <div className="flex flex-1 flex-col gap-4">
              <h3 className="text-3xl font-black tracking-[-0.03em] text-foreground md:text-4xl">
                Go — you, on any computer.
              </h3>
              <p className="max-w-xl text-base leading-relaxed text-muted-foreground md:text-lg">
                Open nosus.foo/go on a borrowed computer, scan with the phone app
                and approve. Your Saved chat opens there — a chat with yourself,
                stored in your own Google Drive under a NO SUS/ folder. Send files
                both ways, print without signing in, and tap End when you&apos;re
                done.
              </p>

              <ul className="mt-2 flex flex-col gap-2 border-t border-border pt-5">
                {goLimits.map((line) => (
                  <li key={line} className="flex items-start gap-3 text-sm leading-relaxed text-muted-foreground">
                    <span className="mt-2 h-1 w-1 shrink-0 bg-foreground" aria-hidden />
                    <span>{line}</span>
                  </li>
                ))}
              </ul>
            </div>

            <Link href="/go" className="btn btn-primary group w-full sm:w-fit">
              Open on this computer
              <ArrowRight className="nudge h-4 w-4" aria-hidden />
            </Link>
          </article>

          {/* Doors 02–03 — planned */}
          {upcoming.map((d) => (
            <article
              key={d.title}
              className="reveal flex flex-col gap-4 rounded-[12px] border border-dashed border-border bg-background p-6 md:p-8 lg:col-span-5"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex h-11 w-11 items-center justify-center rounded-[10px] border border-border">
                  <d.icon className="h-5 w-5 text-muted-foreground" strokeWidth={1.5} aria-hidden />
                </div>
                <div className="flex flex-col items-end gap-2">
                  <span className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground">{d.door}</span>
                  <span className="rounded-pill border border-border px-3 py-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    Coming soon
                  </span>
                </div>
              </div>
              <h3 className="text-2xl font-black tracking-[-0.02em] text-foreground">{d.title}</h3>
              <p className="text-base leading-relaxed text-muted-foreground">{d.text}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
