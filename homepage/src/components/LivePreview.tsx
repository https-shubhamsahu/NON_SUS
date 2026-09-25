"use client";

import { useState } from "react";
import { Eye, ShieldAlert, Ban, CheckCircle, RefreshCw, Smartphone } from "lucide-react";

import SectionHeader from "./ui/SectionHeader";

// What the product is built for — not customer quotes. Never add invented
// testimonials or usage numbers here.
const SCENARIOS = [
  {
    who: "Researchers",
    what: "Send a preprint to reviewers with each page tied to the person it was sent to.",
  },
  {
    who: "Study groups",
    what: "Share solution sets behind touch-to-reveal blur, with a ledger of who opened what.",
  },
  {
    who: "Freelancers",
    what: "Close the deck after the pitch. Expiry and view limits keep it from living forever.",
  },
];

export default function LivePreview() {
  const [activeTab, setActiveTab] = useState<"watermark" | "revoke" | "audit" | "device">("watermark");
  const [isWatermarked, setIsWatermarked] = useState(true);
  const [accessStatus, setAccessStatus] = useState<"secured" | "revoked">("secured");
  const [deviceScanState, setDeviceScanState] = useState<"idle" | "scanning" | "clean">("clean");

  const [previewLogs, setPreviewLogs] = useState([
    { time: "11:23:05", event: "LINK_OPENED", actor: "viewer_01@example.edu", status: "Logged" },
    { time: "11:23:18", event: "WATERMARK_STAMPED", actor: "viewer_01@example.edu", status: "Active" },
    { time: "11:23:20", event: "NEW_DEVICE_FLAGGED", actor: "viewer_01@example.edu", status: "Alert" },
  ]);

  const triggerDeviceScan = () => {
    setDeviceScanState("scanning");
    setTimeout(() => {
      setDeviceScanState("clean");
    }, 1500);
  };

  const handleRevoke = () => {
    setAccessStatus((prev) => (prev === "secured" ? "revoked" : "secured"));
  };

  const handleSimulateLeak = () => {
    const timestamp = new Date().toTimeString().slice(0, 8);
    const newLog = {
      time: timestamp,
      event: "VIEW_LIMIT_REACHED",
      actor: "viewer_01@example.edu",
      status: "Closed",
    };
    setPreviewLogs((prev) => [newLog, ...prev].slice(0, 4));
  };

  const tabBtn = (id: typeof activeTab) =>
    `p-5 text-left border rounded-[12px] transition-colors duration-200 ease-out motion-reduce:transition-none flex items-start gap-4 min-h-[44px] ${
      activeTab === id
        ? "border-foreground bg-card"
        : "border-border bg-transparent hover:border-foreground/40"
    }`;

  return (
    <section id="sharing" className="relative border-b border-border bg-background py-20 md:py-28">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        <SectionHeader
          index="04"
          eyebrow="SecureSend · in the app"
          title="Share a document. See who opened it."
          lede="Each viewer's identity is stamped across the page, so a leak traces back to a person. Set view limits and expiry, revoke any time, and read the log. The panel below is a mock — not a live dashboard."
          className="mb-12 md:mb-16"
        />

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          <div className="lg:col-span-4 flex flex-col gap-4">
            <button type="button" onClick={() => setActiveTab("watermark")} aria-pressed={activeTab === "watermark"} className={tabBtn("watermark")}>
              <Eye className="h-5 w-5 text-foreground shrink-0 mt-0.5" aria-hidden />
              <span className="block">
                <span className="block text-base font-bold uppercase tracking-wider text-foreground">
                  Viewer watermarks
                </span>
                <span className="block text-sm text-muted-foreground mt-1 leading-relaxed">
                  Overlay the recipient’s identity on shared documents.
                </span>
              </span>
            </button>

            <button type="button" onClick={() => setActiveTab("revoke")} aria-pressed={activeTab === "revoke"} className={tabBtn("revoke")}>
              <Ban className="h-5 w-5 text-foreground shrink-0 mt-0.5" aria-hidden />
              <span className="block">
                <span className="block text-base font-bold uppercase tracking-wider text-foreground">
                  Instant revocation
                </span>
                <span className="block text-sm text-muted-foreground mt-1 leading-relaxed">
                  Turn off a share when you no longer want it open.
                </span>
              </span>
            </button>

            <button type="button" onClick={() => setActiveTab("audit")} aria-pressed={activeTab === "audit"} className={tabBtn("audit")}>
              <ShieldAlert className="h-5 w-5 text-foreground shrink-0 mt-0.5" aria-hidden />
              <span className="block">
                <span className="block text-base font-bold uppercase tracking-wider text-foreground">
                  Activity log
                </span>
                <span className="block text-sm text-muted-foreground mt-1 leading-relaxed">
                  See opens and flagged attempt events on a share.
                </span>
              </span>
            </button>

            <button type="button" onClick={() => setActiveTab("device")} aria-pressed={activeTab === "device"} className={tabBtn("device")}>
              <Smartphone className="h-5 w-5 text-foreground shrink-0 mt-0.5" aria-hidden />
              <span className="block">
                <span className="block text-base font-bold uppercase tracking-wider text-foreground">
                  Device checks
                </span>
                <span className="block text-sm text-muted-foreground mt-1 leading-relaxed">
                  Basic checks before opening sensitive material on mobile.
                </span>
              </span>
            </button>
          </div>

          <div className="reveal lg:col-span-8 paper-card p-6 flex flex-col justify-between min-h-[450px] relative overflow-hidden">
            <div className="flex items-center justify-between border-b border-border pb-4 mb-6">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-muted" />
                <span className="text-xs font-mono text-muted-foreground uppercase tracking-wider">
                  Preview · {activeTab}
                </span>
              </div>

              <div className="flex items-center gap-3">
                {activeTab === "watermark" && (
                  <button
                    type="button"
                    onClick={() => setIsWatermarked(!isWatermarked)}
                    className="btn btn-ghost text-xs"
                  >
                    Grid: {isWatermarked ? "ON" : "OFF"}
                  </button>
                )}

                {activeTab === "revoke" && (
                  <button
                    type="button"
                    onClick={handleRevoke}
                    className={`btn text-xs ${
                      accessStatus === "secured" ? "btn-primary" : "btn-ghost"
                    }`}
                  >
                    {accessStatus === "secured" ? "Revoke Access" : "Restore Access"}
                  </button>
                )}

                {activeTab === "audit" && (
                  <button type="button" onClick={handleSimulateLeak} className="btn btn-ghost text-xs">
                    Simulate event
                  </button>
                )}

                {activeTab === "device" && (
                  <button
                    type="button"
                    onClick={triggerDeviceScan}
                    disabled={deviceScanState === "scanning"}
                    className="btn btn-ghost text-xs disabled:opacity-40"
                  >
                    <RefreshCw
                      className={`h-4 w-4 ${
                        deviceScanState === "scanning"
                          ? "animate-spin motion-reduce:animate-none"
                          : ""
                      }`}
                    />
                    Scan Device
                  </button>
                )}
              </div>
            </div>

            <div className="flex-1 flex items-center justify-center relative bg-background border border-border rounded-[12px] overflow-hidden p-6 min-h-[300px]">
              {activeTab === "watermark" && (
                <div className="w-full max-w-md bg-card border border-border p-6 flex flex-col gap-4 relative rounded-[12px]">
                  {isWatermarked && (
                    <div className="absolute inset-0 pointer-events-none grid grid-cols-3 grid-rows-3 select-none opacity-[0.08] rotate-[-12deg] scale-110">
                      {Array.from({ length: 9 }).map((_, i) => (
                        <div
                          key={i}
                          className="text-xs font-mono text-foreground text-center flex items-center justify-center font-bold"
                        >
                          viewer_01@example.edu
                        </div>
                      ))}
                    </div>
                  )}
                  <h4 className="text-base font-bold uppercase tracking-wider text-foreground">
                    Midterm_Notes_Draft.pdf
                  </h4>
                  <p className="text-base text-muted-foreground leading-relaxed">
                    Unit 4: Signals &amp; Systems. Sampling theorem: a band-limited signal can be
                    perfectly reconstructed when sampled above the Nyquist rate. Aliasing occurs
                    below it; anti-aliasing filters must precede the sampler.
                  </p>
                </div>
              )}

              {activeTab === "revoke" && (
                <div className="w-full flex flex-col items-center text-center p-6">
                  {accessStatus === "secured" ? (
                    <div className="bg-card border border-border p-6 max-w-sm rounded-[12px]">
                      <CheckCircle className="h-10 w-10 text-foreground mb-3" />
                      <h4 className="text-base font-bold uppercase tracking-wider text-foreground">
                        Share open
                      </h4>
                      <p className="text-base text-muted-foreground mt-2 leading-relaxed">
                        Document link is active. Use Revoke Access to close it.
                      </p>
                    </div>
                  ) : (
                    <div className="bg-destructive/10 border border-destructive/40 p-6 max-w-sm rounded-[12px]">
                      <Ban className="h-10 w-10 text-destructive mb-3" />
                      <h4 className="text-base font-bold uppercase tracking-wider text-destructive">
                        Access revoked
                      </h4>
                      <p className="text-base text-muted-foreground mt-2 leading-relaxed">
                        This share is closed. Recipients can no longer open the link.
                      </p>
                    </div>
                  )}
                </div>
              )}

              {activeTab === "audit" && (
                <div className="w-full max-w-lg overflow-x-auto">
                  <table className="w-full text-left font-mono text-sm">
                    <thead>
                      <tr className="border-b border-border text-muted-foreground">
                        <th className="py-2 font-medium">Time</th>
                        <th className="py-2 font-medium">Event</th>
                        <th className="py-2 font-medium">Actor</th>
                        <th className="py-2 font-medium">Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      {previewLogs.map((log, idx) => (
                        <tr key={idx} className="border-b border-border/60 text-foreground">
                          <td className="py-2 text-muted-foreground">{log.time}</td>
                          <td className="py-2 font-bold tracking-tight">{log.event}</td>
                          <td className="py-2 text-muted-foreground">{log.actor}</td>
                          <td
                            className={`py-2 ${
                              log.status === "Alert" || log.status === "Closed" ? "text-destructive font-semibold" : "text-foreground"
                            }`}
                          >
                            {log.status}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {activeTab === "device" && (
                <div className="w-full max-w-sm text-center flex flex-col items-center">
                  {deviceScanState === "scanning" && (
                    <div className="flex flex-col items-center gap-3">
                      <RefreshCw className="h-8 w-8 text-foreground animate-spin motion-reduce:animate-none" />
                      <span className="text-sm font-mono uppercase tracking-widest text-muted-foreground">
                        Checking device…
                      </span>
                    </div>
                  )}

                  {deviceScanState === "clean" && (
                    <div className="bg-card border border-border p-6 rounded-[12px]">
                      <CheckCircle className="h-10 w-10 text-foreground mb-3" />
                      <h4 className="text-base font-bold uppercase tracking-wider text-foreground">
                        Checks passed
                      </h4>
                      <p className="text-base text-muted-foreground mt-2 leading-relaxed">
                        Preview only — no live device scan runs in this page.
                      </p>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="mt-16 grid grid-cols-1 gap-px overflow-hidden rounded-[12px] border border-border bg-border md:grid-cols-3">
          {SCENARIOS.map((s) => (
            <div key={s.who} className="flex flex-col gap-2 bg-background p-6 md:p-8">
              <h3 className="font-mono text-xs font-bold uppercase tracking-widest text-foreground">{s.who}</h3>
              <p className="text-base leading-relaxed text-muted-foreground">{s.what}</p>
            </div>
          ))}
        </div>
        <p className="mt-6 text-sm leading-relaxed text-muted-foreground">
          Also in the app: invite-only study groups and a vault for documents your
          group opens under access control.
        </p>
      </div>
    </section>
  );
}
