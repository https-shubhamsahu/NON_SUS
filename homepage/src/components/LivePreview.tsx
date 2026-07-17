"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Eye, ShieldAlert, Ban, CheckCircle, RefreshCw, Smartphone } from "lucide-react";

export default function LivePreview() {
  const [activeTab, setActiveTab] = useState<"watermark" | "revoke" | "audit" | "device">("watermark");
  const [isWatermarked, setIsWatermarked] = useState(true);
  const [accessStatus, setAccessStatus] = useState<"secured" | "revoked">("secured");
  const [deviceScanState, setDeviceScanState] = useState<"idle" | "scanning" | "clean">("clean");

  const [previewLogs, setPreviewLogs] = useState([
    { time: "11:23:05", event: "FILE_VIEWED", actor: "stud_01@tsec.edu", status: "Clean" },
    { time: "11:23:18", event: "SCREENSHOT_ATTEMPT", actor: "stud_01@tsec.edu", status: "Blocked" },
    { time: "11:23:20", event: "COPY_ATTEMPT", actor: "stud_01@tsec.edu", status: "Blocked" },
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
    const timestamp = new Date().toLocaleTimeString();
    const newLog = {
      time: timestamp,
      event: "SCREENSHOT_ATTEMPT",
      actor: "stud_01@tsec.edu",
      status: "Blocked",
    };
    setPreviewLogs((prev) => [newLog, ...prev].slice(0, 4));
  };

  return (
    <section id="live-preview" className="py-24 bg-brand-black border-b border-brand-gray/80 relative">
      <div className="mx-auto max-w-7xl px-6 md:px-8">
        
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="text-[10px] font-bold tracking-widest text-brand-gray-light uppercase mb-2 block">
            Product Simulation
          </span>
          <h2 className="text-3xl md:text-5xl font-black uppercase tracking-tight text-white">
            Experience the Vault
          </h2>
          <p className="text-xs text-brand-gray-light mt-3 leading-relaxed font-medium">
            Toggle security controls to see how NO SUS enforces data sovereignty in real-time.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-stretch">
          
          {/* Simulation Controllers (Left Panel) */}
          <div className="lg:col-span-4 flex flex-col gap-4">
            <button
              onClick={() => setActiveTab("watermark")}
              className={`p-5 text-left border rounded transition-all flex items-start gap-4 ${
                activeTab === "watermark"
                  ? "border-white bg-brand-gray-dark"
                  : "border-brand-gray bg-transparent hover:border-white/30"
              }`}
            >
              <Eye className="h-5 w-5 text-white shrink-0 mt-0.5" />
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-white">
                  Forensic Watermarking
                </h3>
                <p className="text-[11px] text-brand-gray-light mt-1 font-medium">
                  Embed recipient identifiers dynamically to deter and attribute leaks.
                </p>
              </div>
            </button>

            <button
              onClick={() => setActiveTab("revoke")}
              className={`p-5 text-left border rounded transition-all flex items-start gap-4 ${
                activeTab === "revoke"
                  ? "border-white bg-brand-gray-dark"
                  : "border-brand-gray bg-transparent hover:border-white/30"
              }`}
            >
              <Ban className="h-5 w-5 text-white shrink-0 mt-0.5" />
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-white">
                  Instant Revocation
                </h3>
                <p className="text-[11px] text-brand-gray-light mt-1 font-medium">
                  Kill access to any shared document instantly, erasing active sessions.
                </p>
              </div>
            </button>

            <button
              onClick={() => setActiveTab("audit")}
              className={`p-5 text-left border rounded transition-all flex items-start gap-4 ${
                activeTab === "audit"
                  ? "border-white bg-brand-gray-dark"
                  : "border-brand-gray bg-transparent hover:border-white/30"
              }`}
            >
              <ShieldAlert className="h-5 w-5 text-white shrink-0 mt-0.5" />
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-white">
                  Tamper Audit Ledger
                </h3>
                <p className="text-[11px] text-brand-gray-light mt-1 font-medium">
                  Review chained records of user views, download events, and blocked screen captures.
                </p>
              </div>
            </button>

            <button
              onClick={() => setActiveTab("device")}
              className={`p-5 text-left border rounded transition-all flex items-start gap-4 ${
                activeTab === "device"
                  ? "border-white bg-brand-gray-dark"
                  : "border-brand-gray bg-transparent hover:border-white/30"
              }`}
            >
              <Smartphone className="h-5 w-5 text-white shrink-0 mt-0.5" />
              <div>
                <h3 className="text-xs font-bold uppercase tracking-wider text-white">
                  Device Verification
                </h3>
                <p className="text-[11px] text-brand-gray-light mt-1 font-medium">
                  Detect and block user devices running root overrides or layout mirrors.
                </p>
              </div>
            </button>
          </div>

          {/* Interactive Screen Viewer (Right Panel) */}
          <div className="lg:col-span-8 border border-brand-gray bg-brand-gray-dark/40 rounded p-6 flex flex-col justify-between min-h-[450px] relative overflow-hidden">
            
            {/* Screen Header mock */}
            <div className="flex items-center justify-between border-b border-brand-gray pb-4 mb-6">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-brand-gray" />
                <span className="text-[10px] font-mono text-brand-gray-light uppercase tracking-wider">
                  Vault Dashboard // {activeTab.toUpperCase()}
                </span>
              </div>
              
              {/* Context Trigger Options inside Mock */}
              <div className="flex items-center gap-3">
                {activeTab === "watermark" && (
                  <button
                    onClick={() => setIsWatermarked(!isWatermarked)}
                    className="border border-brand-gray px-3 py-1 text-[9px] font-bold uppercase tracking-widest text-white hover:border-white bg-brand-black transition-colors rounded"
                  >
                    Toggle Grid: {isWatermarked ? "ON" : "OFF"}
                  </button>
                )}

                {activeTab === "revoke" && (
                  <button
                    onClick={handleRevoke}
                    className={`px-3 py-1 text-[9px] font-bold uppercase tracking-widest transition-colors rounded ${
                      accessStatus === "secured"
                        ? "bg-red-950 text-red-200 border border-red-800 hover:bg-red-900"
                        : "bg-green-950 text-green-200 border border-green-800 hover:bg-green-900"
                    }`}
                  >
                    {accessStatus === "secured" ? "Revoke Access" : "Restore Access"}
                  </button>
                )}

                {activeTab === "audit" && (
                  <button
                    onClick={handleSimulateLeak}
                    className="border border-brand-gray px-3 py-1 text-[9px] font-bold uppercase tracking-widest text-white hover:border-white bg-brand-black transition-colors rounded"
                  >
                    Simulate Leak
                  </button>
                )}

                {activeTab === "device" && (
                  <button
                    onClick={triggerDeviceScan}
                    disabled={deviceScanState === "scanning"}
                    className="border border-brand-gray px-3 py-1 text-[9px] font-bold uppercase tracking-widest text-white hover:border-white bg-brand-black transition-colors rounded flex items-center gap-1.5"
                  >
                    <RefreshCw className={`h-3 w-3 ${deviceScanState === "scanning" ? "animate-spin" : ""}`} />
                    Scan Device
                  </button>
                )}
              </div>
            </div>

            {/* Screen Content mock viewport */}
            <div className="flex-1 flex items-center justify-center relative bg-brand-black border border-brand-gray/50 rounded overflow-hidden p-6 min-h-[300px]">
              
              <AnimatePresence mode="wait">
                {activeTab === "watermark" && (
                  <motion.div
                    key="watermark"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="w-full max-w-md bg-brand-gray-dark border border-brand-gray p-6 flex flex-col gap-4 relative rounded"
                  >
                    {/* Watermark Diagonal Overlay grid */}
                    {isWatermarked && (
                      <div className="absolute inset-0 pointer-events-none grid grid-cols-3 grid-rows-3 select-none opacity-[0.06] rotate-[-12deg] scale-110">
                        {Array.from({ length: 9 }).map((_, i) => (
                          <div key={i} className="text-[10px] font-mono text-white text-center flex items-center justify-center font-bold">
                            stud_01@tsec.edu
                          </div>
                        ))}
                      </div>
                    )}
                    <h4 className="text-xs font-bold uppercase tracking-wider text-white">
                      Midterm_Notes_Draft.pdf
                    </h4>
                    <p className="text-[10px] text-brand-gray-light leading-relaxed font-medium">
                      Unit 4: Signals &amp; Systems. Sampling theorem: a band-limited signal can be perfectly reconstructed when sampled above the Nyquist rate. Aliasing occurs below it; anti-aliasing filters must precede the sampler. See worked examples 4.2-4.6 before Friday&apos;s review session.
                    </p>
                  </motion.div>
                )}

                {activeTab === "revoke" && (
                  <motion.div
                    key="revoke"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="w-full flex flex-col items-center text-center p-6"
                  >
                    {accessStatus === "secured" ? (
                      <div className="bg-brand-gray-dark border border-brand-gray p-6 max-w-sm rounded">
                        <CheckCircle className="h-10 w-10 text-green-500 mb-3" />
                        <h4 className="text-xs font-bold uppercase tracking-wider text-white">
                          Access Secured
                        </h4>
                        <p className="text-[10px] text-brand-gray-light mt-1.5 leading-normal">
                          Document is online and actively shareable. Click &ldquo;Revoke Access&rdquo; above to test the lock block.
                        </p>
                      </div>
                    ) : (
                      <div className="bg-red-950/20 border border-red-900/50 p-6 max-w-sm rounded">
                        <Ban className="h-10 w-10 text-red-500 mb-3" />
                        <h4 className="text-xs font-bold uppercase tracking-wider text-red-400">
                          ACCESS REVOKED
                        </h4>
                        <p className="text-[10px] text-brand-gray-light mt-1.5 leading-normal">
                          This share token has been destroyed. Active recipient viewports are closed instantly.
                        </p>
                      </div>
                    )}
                  </motion.div>
                )}

                {activeTab === "audit" && (
                  <motion.div
                    key="audit"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="w-full max-w-lg"
                  >
                    <table className="w-full text-left font-mono text-[10px]">
                      <thead>
                        <tr className="border-b border-brand-gray text-brand-gray-light">
                          <th className="py-2">Time</th>
                          <th className="py-2">Event</th>
                          <th className="py-2">Actor</th>
                          <th className="py-2">Ledger Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {previewLogs.map((log, idx) => (
                          <tr key={idx} className="border-b border-brand-gray/30 text-white">
                            <td className="py-2 text-brand-gray-light">{log.time}</td>
                            <td className="py-2 font-bold tracking-tight">{log.event}</td>
                            <td className="py-2 text-brand-gray-light">{log.actor}</td>
                            <td className={`py-2 ${log.status === "Blocked" ? "text-red-400" : "text-green-400"}`}>
                              {log.status}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </motion.div>
                )}

                {activeTab === "device" && (
                  <motion.div
                    key="device"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="w-full max-w-sm text-center flex flex-col items-center"
                  >
                    {deviceScanState === "scanning" && (
                      <div className="flex flex-col items-center gap-3">
                        <RefreshCw className="h-8 w-8 text-white animate-spin" />
                        <span className="text-[10px] font-mono uppercase tracking-widest text-brand-gray-light">
                          Scanning device configurations...
                        </span>
                      </div>
                    )}

                    {deviceScanState === "clean" && (
                      <div className="bg-brand-gray-dark border border-brand-gray p-6 rounded">
                        <CheckCircle className="h-10 w-10 text-white mb-3" />
                        <h4 className="text-xs font-bold uppercase tracking-wider text-white">
                          Device Verified Secure
                        </h4>
                        <p className="text-[10px] text-brand-gray-light mt-1.5 leading-normal">
                          Verification complete. No screen recorders, accessibility hooks, or debuggers detected.
                        </p>
                      </div>
                    )}
                  </motion.div>
                )}
              </AnimatePresence>

            </div>

          </div>

        </div>

      </div>
    </section>
  );
}
