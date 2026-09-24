import { DoorOpen, Inbox, Users } from "lucide-react";

const limits = [
  "Safer than logging into Google on that PC: this computer only sees what you approve, for at most 60 minutes.",
  "Anything you download or print may stay on that computer.",
  "Only approve a code on a screen in front of you.",
  "The computer never receives your Google password or Google token.",
];

export default function ThreeDoors() {
  return (
    <section
      id="doors"
      className="relative border-b border-border bg-background py-16 md:py-24"
    >
      <div className="mx-auto w-full max-w-7xl px-6 md:px-8">
        <h2 className="mb-12 text-[32px] font-black uppercase leading-none tracking-tight text-foreground md:mb-16">
          Three doors
        </h2>

        <div className="grid grid-cols-1 gap-6 md:grid-cols-3 md:gap-8">
          {/* 1. You (Go) — in app when flag enabled */}
          <article
            className="paper-card door-card flex flex-col gap-6 p-6 md:p-8"
            style={{ animationDelay: "0ms" }}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex h-11 w-11 items-center justify-center border border-border bg-muted">
                <DoorOpen
                  className="h-5 w-5 text-foreground"
                  strokeWidth={1.5}
                  aria-hidden
                />
              </div>
              <span className="rounded-pill bg-muted px-3 py-1 text-xs font-semibold uppercase tracking-wider text-foreground">
                In app when enabled
              </span>
            </div>

            <div className="flex flex-1 flex-col gap-3">
              <h3 className="text-xl font-black uppercase tracking-tight text-foreground">
                You (Go)
              </h3>
              <p className="text-base leading-relaxed text-muted-foreground">
                Open nosus.foo/go on a borrowed computer (cyber cafe, college
                lab, print shop). Scan the QR with the NO SUS phone app, confirm
                a 2-digit match code, approve with fingerprint or face. Your
                Saved chat opens there. Saved is a chat with yourself, stored in
                YOUR Google Drive under a NO SUS/ folder. Send files both ways.
                Print without saving a copy into that computer&apos;s Google
                account. Close the tab or tap End on the phone and the session
                ends.
              </p>

              <ul className="mt-2 flex flex-col gap-2 border-t border-border pt-4">
                {limits.map((line) => (
                  <li
                    key={line}
                    className="text-sm leading-relaxed text-muted-foreground"
                  >
                    {line}
                  </li>
                ))}
              </ul>
            </div>

            <a href="/go" className="btn btn-primary mt-auto w-full sm:w-auto">
              Open on this computer
            </a>
          </article>

          {/* 2. Drop — coming soon */}
          <article
            className="paper-card door-card flex flex-col gap-6 p-6 md:p-8"
            style={{ animationDelay: "80ms" }}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex h-11 w-11 items-center justify-center border border-border bg-muted">
                <Inbox
                  className="h-5 w-5 text-foreground"
                  strokeWidth={1.5}
                  aria-hidden
                />
              </div>
              <span className="rounded-pill bg-muted px-3 py-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Coming soon
              </span>
            </div>

            <div className="flex flex-1 flex-col gap-3">
              <h3 className="text-xl font-black uppercase tracking-tight text-foreground">
                Drop
              </h3>
              <p className="text-base leading-relaxed text-muted-foreground">
                People will send you files at yourname.nosus.foo without your
                phone number. The door stays closed by default — you will
                preview and accept before anything reaches your Drive.
              </p>
            </div>
          </article>

          {/* 3. Group drops — coming soon */}
          <article
            className="paper-card door-card flex flex-col gap-6 p-6 md:p-8"
            style={{ animationDelay: "160ms" }}
          >
            <div className="flex items-start justify-between gap-4">
              <div className="flex h-11 w-11 items-center justify-center border border-border bg-muted">
                <Users
                  className="h-5 w-5 text-foreground"
                  strokeWidth={1.5}
                  aria-hidden
                />
              </div>
              <span className="rounded-pill bg-muted px-3 py-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Coming soon
              </span>
            </div>

            <div className="flex flex-1 flex-col gap-3">
              <h3 className="text-xl font-black uppercase tracking-tight text-foreground">
                Group drops
              </h3>
              <p className="text-base leading-relaxed text-muted-foreground">
                A group feed is planned where each member&apos;s copy is saved
                to their own Drive. Later: watermarks so you can see who leaked
                a file. The planned feed is end-to-end encrypted — coming soon,
                not shipping today.
              </p>
            </div>
          </article>
        </div>
      </div>

      <style>{`
        @keyframes doorCardIn {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .door-card {
          animation: doorCardIn 200ms ease-out both;
        }
        @media (prefers-reduced-motion: reduce) {
          .door-card {
            animation: none;
          }
        }
      `}</style>
    </section>
  );
}
