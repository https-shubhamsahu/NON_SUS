import { Monitor, QrCode, Fingerprint, MessageSquare } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

const steps = [
  {
    icon: Monitor,
    title: "Open",
    text: "Go to nosus.foo/go on the computer in front of you. Nothing to install.",
  },
  {
    icon: QrCode,
    title: "Scan",
    text: "Scan the QR on that screen with the NO SUS phone app.",
  },
  {
    icon: Fingerprint,
    title: "Approve",
    text: "Check that both screens show the same two-digit code, then approve with fingerprint or face unlock.",
  },
  {
    icon: MessageSquare,
    title: "Use, then end",
    text: "Your Saved chat appears. Close the tab or tap End on the phone and the session is over.",
  },
];

export default function WorkflowTimeline() {
  return (
    <section id="how-it-works" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto w-full max-w-7xl px-6 md:px-8">
        <SectionHeader
          index="02"
          eyebrow="How Go works"
          title="Four steps. No password typed."
          lede="The phone does the signing-in. The borrowed computer only ever shows what you send it."
        />

        <div className="relative mt-12 md:mt-16">
          {/* Rail behind the step markers (desktop) */}
          <div className="absolute left-0 right-0 top-[22px] hidden h-px bg-border lg:block" aria-hidden="true">
            <div className="rail-fill h-px w-full bg-foreground" />
          </div>

          <ol className="grid grid-cols-1 gap-10 sm:grid-cols-2 lg:grid-cols-4 lg:gap-8">
            {steps.map((step, i) => (
              <li key={step.title} className="reveal relative flex flex-col gap-5">
                <div className="flex items-center gap-2">
                  <span className="relative z-10 flex h-11 w-11 items-center justify-center rounded-full border border-foreground bg-background font-mono text-sm font-bold text-foreground">
                    {String(i + 1).padStart(2, "0")}
                  </span>
                  <span className="relative z-10 bg-background px-2">
                    <step.icon className="h-5 w-5 text-muted-foreground" strokeWidth={1.5} aria-hidden />
                  </span>
                </div>
                <div>
                  <h3 className="text-xl font-black tracking-[-0.02em] text-foreground">{step.title}</h3>
                  <p className="mt-2 text-base leading-relaxed text-muted-foreground">{step.text}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>

        <p className="reveal mt-12 max-w-3xl border-l-2 border-foreground pl-4 text-sm leading-relaxed text-muted-foreground">
          Sessions last at most 60 minutes and end sooner if idle. Anything you
          download or print may stay on that computer.
        </p>
      </div>
    </section>
  );
}
