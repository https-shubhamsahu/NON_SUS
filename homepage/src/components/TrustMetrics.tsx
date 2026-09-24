import { Lock, Link2, ScanFace, Timer } from "lucide-react";

const facts = [
  {
    icon: Lock,
    title: "AES-256-GCM on Go",
    desc: "After the hello, the borrowed-computer session uses AES-256-GCM. The phone keeps the Google token.",
  },
  {
    icon: Link2,
    title: "Keys where they belong",
    desc: "Burn links keep the key in the URL fragment. A single note or file with a pairing code also stores that key on the server for up to 20 minutes.",
  },
  {
    icon: ScanFace,
    title: "2-digit match, not a password",
    desc: "The two-digit code is a check you read on the screen in front of you. Only approve a code on a screen you can see.",
  },
  {
    icon: Timer,
    title: "60-minute session cap",
    desc: "Go sessions last at most 60 minutes. They also end when you close the tab or tap End, and sooner if idle.",
  },
];

export default function TrustMetrics() {
  return (
    <section className="py-24 bg-background border-t border-b border-border relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="grid grid-cols-1 md:grid-cols-12 gap-10 md:gap-12">
          <div className="md:col-span-4 flex flex-col justify-center">
            <h2 className="text-[32px] md:text-4xl font-black uppercase tracking-tight leading-none text-foreground">
              Protocol facts,
              <br />
              not vanity metrics
            </h2>
            <p className="text-base text-muted-foreground mt-4 leading-relaxed max-w-sm">
              Short properties of what ships today — no user counts, uptime
              claims, or audit badges.
            </p>
          </div>

          <div className="md:col-span-8 grid grid-cols-1 sm:grid-cols-2 gap-6">
            {facts.map((item) => (
              <div
                key={item.title}
                className="border border-border bg-card paper-card p-6 flex flex-col gap-4 min-h-[11rem]"
              >
                <item.icon
                  className="h-6 w-6 text-foreground stroke-[1.5]"
                  aria-hidden
                />
                <div>
                  <h3 className="text-base font-bold tracking-tight text-foreground">
                    {item.title}
                  </h3>
                  <p className="text-base text-muted-foreground leading-relaxed mt-2">
                    {item.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
