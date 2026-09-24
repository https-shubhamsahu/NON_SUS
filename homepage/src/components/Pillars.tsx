import { Smartphone, CheckSquare, Stamp } from "lucide-react";

const pillars = [
  {
    icon: Smartphone,
    name: "Phone keeps Google",
    desc: "Your phone holds the Google token. The borrowed computer never gets your Google password or that token.",
  },
  {
    icon: CheckSquare,
    name: "You approve each item",
    desc: "The other screen only shows what you send. Your phone sends only the items you approve.",
  },
  {
    icon: Stamp,
    name: "Tracked when it matters",
    desc: "For documents you still need to share with a name attached, SecureSend can watermark them to the person who opened them — with view limits, expiry, and a view log.",
  },
];

export default function Pillars() {
  return (
    <section className="py-24 bg-background border-b border-border relative">
      <div className="mx-auto max-w-6xl px-6 md:px-8">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
            Three things that stay true
          </h2>
          <p className="mt-4 text-base text-muted-foreground leading-relaxed">
            Built for borrowed computers and careful shares — not slogans.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-px bg-border border border-border overflow-hidden rounded-[12px]">
          {pillars.map((p) => (
            <div
              key={p.name}
              className="bg-card paper-card p-10 flex flex-col gap-5"
            >
              <p.icon
                className="h-8 w-8 text-foreground stroke-[1.5]"
                aria-hidden
              />
              <h3 className="text-2xl font-black uppercase tracking-tight text-foreground">
                {p.name}
              </h3>
              <p className="text-base text-muted-foreground leading-relaxed">
                {p.desc}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
