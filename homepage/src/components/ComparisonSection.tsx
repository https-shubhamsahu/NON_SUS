const rows = [
  {
    capability: "Works without the recipient having an account",
    drive: "Only with basic link sharing, no tracking",
    nosus: "Every time, with full tracking",
  },
  {
    capability: "Shows exactly who opened it",
    drive: "Not by default",
    nosus: "Identity-watermarked automatically",
  },
  {
    capability: "Tamper-evident activity log",
    drive: "Basic activity view",
    nosus: "Hash-chained, independently verifiable",
  },
  {
    capability: "Content that deletes itself after one view",
    drive: "Not available",
    nosus: "Built in",
  },
  {
    capability: "Source code you can actually audit",
    drive: "Closed source",
    nosus: "Fully open source",
  },
];

export default function ComparisonSection() {
  return (
    <section className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-4xl px-6 md:px-8">
        <div className="text-center max-w-2xl mx-auto mb-14">
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white leading-none">
            Why Not Just Use Google Drive?
          </h2>
          <p className="text-xs text-brand-gray-light mt-3 leading-relaxed font-medium">
            Google Drive is good at plenty of things. Tracking who leaked a file isn&apos;t one of them.
          </p>
        </div>

        <div className="overflow-x-auto border border-brand-gray rounded">
          <table className="w-full min-w-[560px] border-collapse text-left">
            <thead>
              <tr className="border-b border-brand-gray bg-brand-gray-dark/40">
                <th className="p-4 text-[10px] font-bold uppercase tracking-widest text-brand-gray-light">
                  Capability
                </th>
                <th className="p-4 text-[10px] font-bold uppercase tracking-widest text-brand-gray-light">
                  Google Drive
                </th>
                <th className="p-4 text-[10px] font-bold uppercase tracking-widest text-white">
                  NO SUS
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, idx) => (
                <tr
                  key={r.capability}
                  className={idx !== rows.length - 1 ? "border-b border-brand-gray/50" : ""}
                >
                  <td className="p-4 text-xs font-bold text-white align-top">{r.capability}</td>
                  <td className="p-4 text-xs text-brand-gray-light align-top">{r.drive}</td>
                  <td className="p-4 text-xs text-white font-medium align-top">{r.nosus}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
