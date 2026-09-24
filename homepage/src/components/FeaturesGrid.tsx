import { Flame, FileUp, Stamp, KeyRound, Users } from "lucide-react";

const features = [
  {
    icon: Flame,
    title: "Burn Notes",
    desc: "Self-destructing text notes encrypted in the browser. Share a link; the note opens once and then burns.",
  },
  {
    icon: FileUp,
    title: "Burn Files",
    desc: "Drop a file, encrypt it locally, and send an expiring link. No account required for the recipient.",
  },
  {
    icon: Stamp,
    title: "Watermarked Shares",
    desc: "SecureSend stamps each viewer’s identity on the document so a leak traces back to a person.",
  },
  {
    icon: KeyRound,
    title: "Pairing Codes",
    desc: "Optional two-digit codes for a single note or file. The key is held for up to 20 minutes while the code is valid.",
  },
  {
    icon: Users,
    title: "Groups & Vault",
    desc: "Invite-only study groups and a vault for shared documents your team can open under access control.",
  },
];

export default function FeaturesGrid() {
  return (
    <section id="features" className="py-24 bg-background border-b border-border relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="max-w-2xl mb-16">
          <p className="text-xs font-bold tracking-widest text-muted-foreground uppercase mb-3">
            Also in the product
          </p>
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground">
            Supporting capabilities
          </h2>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground max-w-lg">
            Tools that ship today alongside burn notes and files — useful, not the headline.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feat) => (
            <div
              key={feat.title}
              className="paper-card p-8 flex flex-col justify-between min-h-[220px] transition-colors duration-200 ease-out motion-reduce:transition-none"
            >
              <div className="flex flex-col gap-4">
                <div className="w-11 h-11 min-w-[44px] min-h-[44px] border border-border flex items-center justify-center bg-muted rounded-[12px]">
                  <feat.icon className="h-5 w-5 text-foreground stroke-[1.5]" />
                </div>
                <h3 className="text-base font-bold uppercase tracking-wider text-foreground">
                  {feat.title}
                </h3>
              </div>

              <p className="text-base text-muted-foreground leading-relaxed mt-4">
                {feat.desc}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
