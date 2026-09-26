import SectionHeader from "./ui/SectionHeader";

const columns = {
  sharedPc: "WhatsApp Web / Gmail on a shared PC",
  drive: "Google Drive in that browser",
  nosus: "NO SUS Go",
} as const;

const rows = [
  {
    capability: "Google sign-in on that PC",
    sharedPc: "You sign the real WhatsApp Web or Gmail account in. Session, downloads, and password-manager prompts can remain.",
    drive: "The Google account is logged in on that browser.",
    nosus: "No Google sign-in on that PC. The phone holds the token.",
  },
  {
    capability: "What the other screen can see",
    sharedPc: "Full inbox or chat once signed in.",
    drive: "Whatever that Drive session can open.",
    nosus: "Only items you approve on your phone.",
  },
  {
    capability: "How long access lasts",
    sharedPc: "Until you sign out — if you remember.",
    drive: "Until you sign out of that browser.",
    nosus: "At most 60 minutes; also ends when the tab closes or you tap End.",
  },
  {
    capability: "Downloads and prints",
    sharedPc: "Can remain on the shared machine.",
    drive: "Can remain on the shared machine.",
    nosus: "May still remain on that computer — same honest limit.",
  },
  {
    capability: "Where saved files live",
    sharedPc: "Wherever that signed-in account stores them.",
    drive: "In Drive under that PC session.",
    nosus: "In your own Google Drive (NO SUS/ folder). Token stays on the phone.",
  },
];

export default function ComparisonSection() {
  return (
    <section id="compare" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <SectionHeader
          index="04"
          eyebrow="Versus signing in"
          title="Why not just log in on the shared PC?"
          lede="Honest contrasts only — including the one limit NO SUS shares with everything else."
        />

        {/* Desktop: table */}
        <div className="reveal mt-12 hidden overflow-hidden rounded-[12px] border border-border md:mt-16 md:block">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="border-b border-border">
                <th scope="col" className="w-[22%] p-5 font-mono text-xs font-semibold uppercase tracking-widest text-muted-foreground">
                  Question
                </th>
                <th scope="col" className="p-5 font-mono text-xs font-semibold uppercase tracking-widest text-muted-foreground">
                  {columns.sharedPc}
                </th>
                <th scope="col" className="p-5 font-mono text-xs font-semibold uppercase tracking-widest text-muted-foreground">
                  {columns.drive}
                </th>
                <th scope="col" className="bg-card p-5 font-mono text-xs font-bold uppercase tracking-widest text-foreground">
                  {columns.nosus}
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, idx) => (
                <tr key={r.capability} className={idx !== rows.length - 1 ? "border-b border-border" : ""}>
                  <th scope="row" className="p-5 align-top text-base font-bold text-foreground">
                    {r.capability}
                  </th>
                  <td className="p-5 align-top text-sm leading-relaxed text-muted-foreground">{r.sharedPc}</td>
                  <td className="p-5 align-top text-sm leading-relaxed text-muted-foreground">{r.drive}</td>
                  <td className="bg-card p-5 align-top text-sm font-medium leading-relaxed text-foreground">{r.nosus}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Mobile: one card per question */}
        <div className="mt-12 flex flex-col gap-4 md:hidden">
          {rows.map((r) => (
            <div key={r.capability} className="reveal paper-card p-5">
              <h3 className="text-base font-bold text-foreground">{r.capability}</h3>
              <dl className="mt-4 flex flex-col gap-3 text-sm leading-relaxed">
                <div className="rounded-[8px] border border-foreground p-3">
                  <dt className="font-mono text-[11px] font-bold uppercase tracking-widest text-foreground">{columns.nosus}</dt>
                  <dd className="mt-1 text-foreground">{r.nosus}</dd>
                </div>
                <div>
                  <dt className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground">{columns.sharedPc}</dt>
                  <dd className="mt-1 text-muted-foreground">{r.sharedPc}</dd>
                </div>
                <div>
                  <dt className="font-mono text-[11px] uppercase tracking-widest text-muted-foreground">{columns.drive}</dt>
                  <dd className="mt-1 text-muted-foreground">{r.drive}</dd>
                </div>
              </dl>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
