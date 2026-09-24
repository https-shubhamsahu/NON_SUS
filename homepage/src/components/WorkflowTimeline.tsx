import { Monitor, QrCode, Fingerprint, MessageSquare } from "lucide-react";

const steps = [
  {
    icon: Monitor,
    num: "01",
    title: "Open",
    text: "Open nosus.foo/go on the computer.",
  },
  {
    icon: QrCode,
    num: "02",
    title: "Scan",
    text: "Scan the QR with the NO SUS app.",
  },
  {
    icon: Fingerprint,
    num: "03",
    title: "Approve",
    text: "Check the 2-digit match code and approve with fingerprint or face.",
  },
  {
    icon: MessageSquare,
    num: "04",
    title: "Use & end",
    text: "Your Saved chat appears. Close the tab or tap End and the session ends.",
  },
];

export default function WorkflowTimeline() {
  return (
    <section
      id="how-it-works"
      className="relative border-b border-border bg-background py-16 md:py-24"
    >
      <div className="mx-auto w-full max-w-7xl px-6 md:px-8">
        <h2 className="mb-12 text-[32px] font-black uppercase leading-none tracking-tight text-foreground md:mb-16">
          How Go works
        </h2>

        <ol className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 md:gap-8">
          {steps.map((step) => (
            <li key={step.num} className="paper-card flex flex-col gap-5 p-6 md:p-8">
              <div className="flex items-start justify-between gap-4">
                <div className="flex h-11 w-11 items-center justify-center border border-border bg-muted">
                  <step.icon
                    className="h-5 w-5 text-foreground"
                    strokeWidth={1.5}
                    aria-hidden
                  />
                </div>
                <span className="font-mono text-2xl font-black text-muted-foreground/40">
                  {step.num}
                </span>
              </div>

              <div>
                <h3 className="text-base font-bold uppercase tracking-wider text-foreground">
                  {step.title}
                </h3>
                <p className="mt-2 text-base leading-relaxed text-muted-foreground">
                  {step.text}
                </p>
              </div>
            </li>
          ))}
        </ol>

        <p className="mt-8 max-w-3xl text-sm leading-relaxed text-muted-foreground">
          Sessions last at most 60 minutes. Anything you download or print may
          stay on that computer.
        </p>
      </div>
    </section>
  );
}
