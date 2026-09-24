"use client";

import { useState } from "react";
import { Key, Cpu, ChevronRight, HelpCircle } from "lucide-react";

export default function SecurityEditorial() {
  const [showTechnicalSpecs, setShowTechnicalSpecs] = useState(false);

  const keyStatements = [
    {
      title: "The borrowed PC never gets your Google login.",
      desc: "Your phone holds the Google token. That computer only sees items you approve, for at most 60 minutes.",
    },
    {
      title: "Sessions end when you leave.",
      desc: "A Go session caps at 60 minutes. It also ends when you close the tab or tap End, and sooner if idle.",
    },
    {
      title: "Downloads and prints can stick around.",
      desc: "Anything you download or print may stay on that computer. Approve only what you are willing to leave behind.",
    },
    {
      title: "Pairing codes are honest about keys.",
      desc: "Burn notes and files encrypt in the browser. A normal burn link keeps the key in the URL fragment. A single note or file with a two-digit pairing code also stores that key on the server for up to 20 minutes.",
    },
  ];

  return (
    <section
      id="security"
      className="py-24 bg-background border-b border-border relative"
    >
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-6 flex flex-col justify-center gap-8">
            <div>
              <h2 className="text-[32px] md:text-5xl font-black uppercase tracking-tight text-foreground leading-none">
                Shared screens.
                <br />
                Honest limits.
              </h2>
              <p className="mt-4 text-base text-muted-foreground leading-relaxed max-w-md">
                Safer than logging into Google on that PC: this computer only
                sees what you approve, for at most 60 minutes. Only approve a
                code on a screen in front of you.
              </p>
            </div>

            <div className="flex flex-col gap-6">
              {keyStatements.map((state) => (
                <div key={state.title} className="flex gap-4 items-start">
                  <div
                    className="w-1.5 h-1.5 bg-foreground rounded-full shrink-0 mt-2.5"
                    aria-hidden
                  />
                  <div>
                    <h3 className="text-base font-bold tracking-tight text-foreground">
                      {state.title}
                    </h3>
                    <p className="text-base text-muted-foreground mt-1.5 leading-relaxed">
                      {state.desc}
                    </p>
                  </div>
                </div>
              ))}
            </div>

            <div>
              <button
                type="button"
                onClick={() => setShowTechnicalSpecs(!showTechnicalSpecs)}
                className="inline-flex items-center gap-1.5 min-h-11 px-1 text-sm font-bold uppercase tracking-widest text-foreground hover:text-muted-foreground transition-colors duration-200 ease-out group focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring motion-reduce:transition-none"
              >
                How the crypto fits
                <ChevronRight
                  className={`h-4 w-4 transition-transform duration-200 ease-out motion-reduce:transition-none ${
                    showTechnicalSpecs
                      ? "rotate-90"
                      : "group-hover:translate-x-1 motion-reduce:group-hover:translate-x-0"
                  }`}
                  aria-hidden
                />
              </button>
            </div>
          </div>

          <div className="lg:col-span-6 border border-border bg-card paper-card p-8 min-h-[380px] flex flex-col justify-between relative overflow-hidden">
            {!showTechnicalSpecs ? (
              <div className="flex flex-col justify-between h-full gap-8">
                <div className="flex items-center gap-2 border-b border-border pb-3">
                  <Key className="h-5 w-5 text-foreground" aria-hidden />
                  <span className="text-xs font-mono tracking-widest uppercase text-muted-foreground">
                    What stays where
                  </span>
                </div>
                <div className="py-4">
                  <p className="text-base text-muted-foreground leading-relaxed">
                    For a borrowed-computer Go session, the relay is not your
                    Google account — Supabase relays ciphertext and stores a
                    hash of the session id, not the Google token. Saved files
                    live in your own Google Drive (a NO SUS/ folder) with
                    drive.file scope: the app sees files it created.
                  </p>
                </div>
                <div className="border-t border-border pt-4 flex flex-wrap gap-4 items-center justify-between text-xs font-mono text-muted-foreground">
                  <span>GO SESSION: AES-256-GCM</span>
                  <span>CAP: 60 MIN</span>
                </div>
              </div>
            ) : (
              <div className="flex flex-col justify-between h-full gap-6 font-mono text-sm">
                <div className="flex items-center gap-2 border-b border-border pb-3">
                  <Cpu className="h-5 w-5 text-foreground" aria-hidden />
                  <span className="text-xs tracking-widest uppercase text-muted-foreground">
                    Protocol notes
                  </span>
                </div>

                <div className="flex flex-col gap-4 text-muted-foreground text-base font-sans">
                  <div className="flex flex-col sm:flex-row sm:justify-between gap-1 border-b border-border pb-2">
                    <span className="text-foreground font-bold">
                      Go session crypto
                    </span>
                    <span>AES-256-GCM after hello</span>
                  </div>
                  <div className="flex flex-col sm:flex-row sm:justify-between gap-1 border-b border-border pb-2">
                    <span className="text-foreground font-bold">
                      Burn link key
                    </span>
                    <span>URL fragment (#…)</span>
                  </div>
                  <div className="flex flex-col sm:flex-row sm:justify-between gap-1 border-b border-border pb-2">
                    <span className="text-foreground font-bold">
                      Pairing-code key
                    </span>
                    <span>On server ≤ 20 min</span>
                  </div>
                  <div className="flex flex-col sm:flex-row sm:justify-between gap-1 border-b border-border pb-2">
                    <span className="text-foreground font-bold">
                      Multi-file shares
                    </span>
                    <span>Key not sent that way</span>
                  </div>
                </div>

                <div className="border border-border p-4 bg-muted text-base text-muted-foreground leading-relaxed flex items-start gap-2.5 font-sans">
                  <HelpCircle
                    className="h-5 w-5 text-foreground shrink-0 mt-0.5"
                    aria-hidden
                  />
                  <span>
                    The two-digit match code is a check you read on the screen
                    in front of you — not a password. Fragment keys stay in the
                    browser URL for normal burn links; pairing codes are the
                    exception that stores a key briefly.
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
