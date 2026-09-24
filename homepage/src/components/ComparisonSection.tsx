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
    <section className="py-24 bg-background border-b border-border relative">
      <div className="mx-auto max-w-5xl px-6 md:px-8">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
            Vs signing into WhatsApp Web or Gmail on a shared PC
          </h2>
          <p className="text-base text-muted-foreground mt-4 leading-relaxed">
            Honest contrasts only — including how Google Drive in a browser on
            that PC differs from saving via NO SUS with the token on your phone.
          </p>
        </div>

        <div className="overflow-x-auto border border-border paper-card">
          <table className="w-full min-w-[720px] border-collapse text-left">
            <thead>
              <tr className="border-b border-border bg-muted">
                <th className="p-4 text-xs font-bold uppercase tracking-widest text-muted-foreground min-w-[9rem]">
                  Question
                </th>
                <th className="p-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">
                  WhatsApp Web / Gmail on a shared PC
                </th>
                <th className="p-4 text-xs font-bold uppercase tracking-widest text-muted-foreground">
                  Google Drive in that browser
                </th>
                <th className="p-4 text-xs font-bold uppercase tracking-widest text-foreground">
                  NO SUS Go
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, idx) => (
                <tr
                  key={r.capability}
                  className={
                    idx !== rows.length - 1 ? "border-b border-border" : ""
                  }
                >
                  <td className="p-4 text-base font-bold text-foreground align-top">
                    {r.capability}
                  </td>
                  <td className="p-4 text-base text-muted-foreground align-top">
                    {r.sharedPc}
                  </td>
                  <td className="p-4 text-base text-muted-foreground align-top">
                    {r.drive}
                  </td>
                  <td className="p-4 text-base text-foreground align-top">
                    {r.nosus}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
