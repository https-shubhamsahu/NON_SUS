import { Monitor, QrCode, LockKeyhole, MessageSquare } from "lucide-react";

import PairingDemo from "./PairingDemo";
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
    icon: LockKeyhole,
    title: "Approve",
    text: "Pick the two-digit code the computer shows from the three on your phone, then approve with your phone's screen lock.",
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
        <div className="grid grid-cols-1 items-center gap-12 lg:grid-cols-12 lg:gap-16">
          <div className="flex flex-col gap-6 lg:col-span-5">
            <SectionHeader
              index="02"
              eyebrow="How Go works"
              title="Four steps. No password typed."
              lede="The phone does the signing-in. The borrowed computer only ever shows what you send it."
            />
            <p className="reveal text-sm leading-relaxed text-muted-foreground">
              Go is in early access. It shows up in the app once it&apos;s
              enabled for your account.
            </p>
          </div>
          <div className="reveal lg:col-span-7">
            <PairingDemo />
          </div>
        </div>

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
