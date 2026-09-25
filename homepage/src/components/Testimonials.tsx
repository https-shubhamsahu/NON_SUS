



export default function Testimonials() {
  // Honest scenario cards — what the product is built for, not invented
  // customer quotes. Do not add fabricated testimonials or usage claims.
  const scenarios = [
    {
      scenario: "Sharing preprint drafts with external reviewers is nerve-wracking. Dynamic watermarking ties every viewed page to the reviewer it was sent to, so a leaked draft is traceable pre-publication.",
      author: "Researchers",
      role: "Preprints · Peer Review · Lab Notes",
    },
    {
      scenario: "Study groups share draft solutions and notes. Touch-to-reveal blur prevents passive drive-by copying, and the group audit ledger shows exactly who opened what, when.",
      author: "Study Groups",
      role: "Notes · Solution Sets · Slides",
    },
    {
      scenario: "After a client presentation, revoke access to the deck instantly. Expiry windows and view limits keep shared material under your control after it leaves your hands.",
      author: "Independent Consultants",
      role: "Decks · Proposals · Contracts",
    },
  ];

  return (
    <section id="use-cases" className="py-24 bg-background border-b border-border relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">

        <div className="text-center max-w-2xl mx-auto mb-16">
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
            Where a Leak Actually Costs Something
          </h2>
          <p className="text-sm text-muted-foreground mt-4 leading-relaxed font-medium">
            Scenarios the product is built for, not customer testimonials.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {scenarios.map((item, idx) => (
            <div
              key={idx}
              className="border border-border p-8 bg-card flex flex-col justify-between min-h-[220px] rounded relative paper-card"
            >
              <p className="text-sm text-muted-foreground leading-relaxed font-medium">
                {item.scenario}
              </p>
              
              <div className="mt-6 border-t border-border pt-4">
                <h3 className="text-xs font-bold uppercase tracking-wider text-foreground">
                  {item.author}
                </h3>
                <span className="text-xs font-mono text-muted-foreground uppercase mt-0.5 block">
                  {item.role}
                </span>
              </div>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
