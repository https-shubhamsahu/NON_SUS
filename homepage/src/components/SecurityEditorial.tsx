import { Smartphone, CheckSquare, Timer, Download } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

// Copy must never outrun the cryptography (AGENTS.md §0.3). Limits are
// stated as plainly as strengths.
const statements = [
  {
    icon: Smartphone,
    title: "The borrowed PC never gets your Google login.",
    desc: "Your phone holds the Google token. That computer only sees the items you approve.",
  },
  {
    icon: CheckSquare,
    title: "You approve every item.",
    desc: "The other screen shows only what your phone sends. The two-digit match code is a check you read on the screen in front of you — not a password.",
  },
  {
    icon: Timer,
    title: "Sessions end when you leave.",
    desc: "A Go session lasts at most 60 minutes. It also ends when you close the tab or tap End, and sooner if idle.",
  },
  {
    icon: Download,
    title: "Downloads and prints can stick around.",
    desc: "Anything you download or print may stay on that computer. Approve only what you are willing to leave behind.",
  },
];

const ledger = [
  { item: "Go session traffic", where: "AES-256-GCM after the P-256 hello" },
  { item: "Your Google token", where: "On your phone — never the borrowed PC" },
  { item: "Go relay", where: "Ciphertext + a hash of the session id" },
  { item: "Saved files", where: "Your Drive, NO SUS/ folder (drive.file)" },
  { item: "Burn link key", where: "URL fragment (#…), never sent to us" },
  { item: "Pairing-code key", where: "On the server ≤ 20 min, then deleted" },
  { item: "Multi-file shares", where: "Link only — no pairing code" },
];

export default function SecurityEditorial() {
  return (
    <section id="security" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="grid grid-cols-1 gap-12 lg:grid-cols-12 lg:gap-16">
          <div className="flex flex-col gap-10 lg:col-span-6">
            <SectionHeader
              index="06"
              eyebrow="Security"
              title={
                <>
                  Shared screens.
                  <br />
                  Honest limits.
                </>
              }
              lede="Safer than logging into Google on that PC — and clear about the one thing no website can stop."
            />

            <ul className="flex flex-col gap-7">
              {statements.map((s) => (
                <li key={s.title} className="reveal flex items-start gap-4">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] border border-border bg-card">
                    <s.icon className="h-[18px] w-[18px] text-foreground" strokeWidth={1.5} aria-hidden />
                  </span>
                  <div>
                    <h3 className="text-base font-bold text-foreground">{s.title}</h3>
                    <p className="mt-1.5 text-base leading-relaxed text-muted-foreground">{s.desc}</p>
                  </div>
                </li>
              ))}
            </ul>
          </div>

          <div className="reveal lg:col-span-6 lg:pt-12">
            <div className="paper-card overflow-hidden">
              <div className="flex items-center justify-between border-b border-border px-6 py-4 font-mono text-xs uppercase tracking-widest text-muted-foreground">
                <span>What stays where</span>
                <span className="text-foreground">Ledger</span>
              </div>
              <dl>
                {ledger.map((row, i) => (
                  <div
                    key={row.item}
                    className={`grid grid-cols-1 gap-1 px-6 py-4 sm:grid-cols-[minmax(0,11rem)_1fr] sm:gap-6 ${
                      i !== ledger.length - 1 ? "border-b border-border" : ""
                    }`}
                  >
                    <dt className="text-sm font-bold text-foreground">{row.item}</dt>
                    <dd className="font-mono text-sm text-muted-foreground">{row.where}</dd>
                  </div>
                ))}
              </dl>
              <p className="border-t border-border bg-muted/40 px-6 py-4 text-sm leading-relaxed text-muted-foreground">
                Browsers can&apos;t block screenshots, so on the web NO SUS deters
                and traces with watermarks and touch-to-reveal blur. The Android
                app blocks screenshots and screen recording of protected documents.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
