"use client";

import { useRef, useState, DragEvent } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  FileUp,
  Lock,
  Check,
  Copy,
  AlertTriangle,
  RotateCcw,
} from "lucide-react";
import {
  createBurnFile,
  createBurnNote,
  FILE_MAX_BYTES,
  NOTE_MAX_CHARS,
} from "@/lib/burnApi";
import { BorderTrail } from "@/components/ui/border-trail";

type Tab = "note" | "file";
type Phase = "idle" | "working" | "done" | "error";

const EXPIRY_CHOICES = [
  { hours: 1, label: "1 HOUR" },
  { hours: 24, label: "24 HOURS" },
  { hours: 168, label: "7 DAYS" },
];

export default function BurnTool() {
  const [tab, setTab] = useState<Tab>("file");
  const [phase, setPhase] = useState<Phase>("idle");
  const [statusLabel, setStatusLabel] = useState("");
  const [error, setError] = useState("");
  const [link, setLink] = useState("");
  const [copied, setCopied] = useState(false);
  const [noteText, setNoteText] = useState("");
  const [expiryHours, setExpiryHours] = useState(24);
  const [dragOver, setDragOver] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const reset = () => {
    setPhase("idle");
    setError("");
    setLink("");
    setCopied(false);
    setStatusLabel("");
  };

  const switchTab = (next: Tab) => {
    setTab(next);
    reset();
  };

  const fail = (e: unknown) => {
    setError(e instanceof Error ? e.message : "Something went wrong. Please try again.");
    setPhase("error");
  };

  const handleCreateNote = async () => {
    const text = noteText.trim();
    if (!text) return;
    setPhase("working");
    setStatusLabel("ENCRYPTING IN BROWSER…");
    try {
      const url = await createBurnNote(text);
      setLink(url);
      setNoteText("");
      setPhase("done");
    } catch (e) {
      fail(e);
    }
  };

  const handleFile = async (file: File | undefined | null) => {
    if (!file || phase === "working") return;
    setPhase("working");
    try {
      const url = await createBurnFile(file, expiryHours, (p) => {
        setStatusLabel(
          p.phase === "encrypting"
            ? "ENCRYPTING IN BROWSER…"
            : p.phase === "uploading"
              ? "UPLOADING CIPHERTEXT…"
              : "SEALING…",
        );
      });
      setLink(url);
      setPhase("done");
    } catch (e) {
      fail(e);
    }
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    handleFile(e.dataTransfer.files?.[0]);
  };

  const copyLink = async () => {
    await navigator.clipboard.writeText(link);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="relative flex flex-col items-center justify-center py-6">
      {/* Dynamic Keyframes for morphing liquid shape */}
      <style>{`
        @keyframes morph-blob {
          0%, 100% { border-radius: 50% 50% 50% 50%; }
          33% { border-radius: 46% 54% 44% 56% / 53% 45% 55% 47%; }
          66% { border-radius: 54% 46% 56% 44% / 45% 55% 45% 55%; }
        }
        .liquid-blob {
          animation: morph-blob 8s ease-in-out infinite;
        }
        .liquid-blob:hover {
          animation-duration: 4s;
        }
      `}</style>

      {/* Interactive Waves / concentric rings leaving the circle */}
      {isHovered && (
        <>
          <motion.div
            className="absolute w-[350px] h-[350px] sm:w-[390px] sm:h-[390px] rounded-full border-2 border-white/20 pointer-events-none z-0"
            initial={{ scale: 1, opacity: 0.6 }}
            animate={{ scale: 1.35, opacity: 0 }}
            transition={{ repeat: Infinity, duration: 2.2, ease: "easeOut" }}
          />
          <motion.div
            className="absolute w-[350px] h-[350px] sm:w-[390px] sm:h-[390px] rounded-full border-2 border-white/10 pointer-events-none z-0"
            initial={{ scale: 1, opacity: 0.6 }}
            animate={{ scale: 1.6, opacity: 0 }}
            transition={{ repeat: Infinity, duration: 2.2, delay: 0.7, ease: "easeOut" }}
          />
          <motion.div
            className="absolute w-[350px] h-[350px] sm:w-[390px] sm:h-[390px] rounded-full border border-dashed border-white/5 pointer-events-none z-0"
            initial={{ scale: 1, opacity: 0.4 }}
            animate={{ scale: 1.95, opacity: 0 }}
            transition={{ repeat: Infinity, duration: 2.2, delay: 1.4, ease: "easeOut" }}
          />
        </>
      )}

      {/* Main Morphing Circle Box */}
      <div
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        className={`relative z-10 w-[340px] h-[340px] sm:w-[380px] sm:h-[380px] border-4 border-white/80 bg-brand-black/95 text-left flex flex-col items-center justify-center p-6 shadow-[8px_8px_0px_0px_rgba(255,255,255,0.05)] transition-all duration-300 liquid-blob ${
          dragOver ? "scale-105 border-white bg-white/5" : ""
        }`}
      >
        <BorderTrail
          className="bg-white/80"
          style={{
            boxShadow:
              "0px 0px 40px 20px rgb(255 255 255 / 80%), 0 0 80px 40px rgb(255 255 255 / 40%)",
          }}
          size={140}
          transition={{
            repeat: Infinity,
            duration: 6,
            ease: "linear",
          }}
        />
        <AnimatePresence mode="wait">
          {phase === "working" ? (
            <motion.div
              key="working"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center justify-center gap-4 text-center"
            >
              <div className="relative">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1.5, repeat: Infinity, ease: "linear" }}
                  className="w-16 h-16 border-2 border-dashed border-white rounded-full flex items-center justify-center"
                />
                <div className="absolute inset-0 flex items-center justify-center">
                  <Lock className="h-5 w-5 text-white" />
                </div>
              </div>
              <span className="text-[10px] font-mono tracking-widest text-brand-gray-light animate-pulse text-center max-w-[200px] uppercase">
                {statusLabel}
              </span>
            </motion.div>
          ) : phase === "done" ? (
            <motion.div
              key="done"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center justify-center gap-4 text-center w-full"
            >
              <div className="flex items-center gap-2 text-white">
                <Lock className="h-4 w-4 text-green-400" />
                <span className="text-[10px] font-bold tracking-widest uppercase">
                  LINK MINTED
                </span>
              </div>

              <div className="w-[85%] z-20">
                <input
                  type="text"
                  readOnly
                  value={link}
                  onFocus={(e) => e.target.select()}
                  className="w-full bg-brand-black border border-white/20 px-3 py-2 text-[10px] font-mono text-brand-gray-light rounded-xl text-center focus:outline-none min-w-0"
                />
              </div>

              <button
                onClick={copyLink}
                className="bg-white text-black px-6 py-2.5 text-[9px] font-bold uppercase tracking-widest hover:bg-black hover:text-white border border-white transition-all rounded-full flex items-center gap-2 z-20"
              >
                {copied ? (
                  <>
                    <Check className="h-3 w-3" /> Copied
                  </>
                ) : (
                  <>
                    <Copy className="h-3 w-3" /> Copy Link
                  </>
                )}
              </button>

              <p className="text-[8px] text-brand-gray-light leading-relaxed max-w-[220px]">
                The key lives in this URL hash<span className="text-white">.</span> We cannot recover it<span className="text-white">.</span> One-time read only<span className="text-white">.</span>
              </p>

              <button
                onClick={reset}
                className="inline-flex items-center gap-1.5 text-[9px] font-bold uppercase tracking-widest text-brand-gray-light hover:text-white transition-colors z-20"
              >
                <RotateCcw className="h-3 w-3" /> Burn another
              </button>
            </motion.div>
          ) : phase === "error" ? (
            <motion.div
              key="error"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center justify-center gap-4 text-center w-full p-4"
            >
              <AlertTriangle className="h-8 w-8 text-white" />
              <span className="text-[10px] font-mono text-brand-gray-light uppercase leading-relaxed max-w-[220px]">
                {error}
              </span>
              <button
                onClick={reset}
                className="bg-white text-black px-5 py-2 text-[9px] font-bold uppercase tracking-widest hover:bg-black hover:text-white border border-white transition-all rounded-full flex items-center gap-2 z-20"
              >
                <RotateCcw className="h-3 w-3" /> Try again
              </button>
            </motion.div>
          ) : (
            <motion.div
              key="form"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="flex flex-col items-center justify-center w-full h-full text-center relative z-20"
            >
              {/* Tabs Capsule */}
              <div className="flex border border-white/20 bg-brand-black rounded-full overflow-hidden mb-5">
                <button
                  onClick={() => switchTab("note")}
                  className={`px-4 py-1.5 text-[9px] font-bold uppercase tracking-wider transition-colors ${
                    tab === "note" ? "bg-white text-black" : "text-brand-gray-light hover:text-white"
                  }`}
                >
                  Note
                </button>
                <button
                  onClick={() => switchTab("file")}
                  className={`px-4 py-1.5 text-[9px] font-bold uppercase tracking-wider transition-colors ${
                    tab === "file" ? "bg-white text-black" : "text-brand-gray-light hover:text-white"
                  }`}
                >
                  File
                </button>
              </div>

              {tab === "note" ? (
                <div className="flex flex-col items-center w-full">
                  <textarea
                    value={noteText}
                    onChange={(e) => setNoteText(e.target.value.slice(0, NOTE_MAX_CHARS))}
                    placeholder="WRITE A SECRET NOTE…"
                    className="w-[85%] h-[120px] bg-brand-black/50 border border-white/10 hover:border-white/30 focus:border-white focus:outline-none p-3.5 text-[10px] font-mono text-center text-white resize-none rounded-xl"
                  />
                  {/* Expiry & Counter */}
                  <div className="flex items-center justify-between w-[80%] mt-3 text-[8px] font-mono text-brand-gray-light">
                    <span>{noteText.length}/{NOTE_MAX_CHARS}</span>
                    <select
                      value={expiryHours}
                      onChange={(e) => setExpiryHours(Number(e.target.value))}
                      className="bg-brand-black border border-white/10 text-white rounded px-1.5 py-0.5 focus:outline-none"
                    >
                      {EXPIRY_CHOICES.map((c) => (
                        <option key={c.hours} value={c.hours}>{c.label}</option>
                      ))}
                    </select>
                  </div>
                  {/* Burn Button */}
                  <button
                    onClick={handleCreateNote}
                    disabled={!noteText.trim()}
                    className={`mt-5 px-6 py-2.5 text-[9px] font-bold uppercase tracking-widest rounded-full border transition-all ${
                      noteText.trim()
                        ? "bg-white text-black border-white hover:bg-black hover:text-white active:scale-95"
                        : "bg-transparent text-white/30 border-white/10 cursor-not-allowed"
                    }`}
                  >
                    Burn Note
                  </button>
                </div>
              ) : (
                <div className="flex flex-col items-center w-full">
                  {/* Circular Upload Area */}
                  <div
                    onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                    onDragLeave={() => setDragOver(false)}
                    onDrop={handleDrop}
                    onClick={() => fileInputRef.current?.click()}
                    className={`w-[85%] h-[140px] border-2 border-dashed rounded-2xl flex flex-col items-center justify-center cursor-pointer transition-colors p-4 ${
                      dragOver ? "border-white bg-white/5" : "border-white/20 hover:border-white/40 bg-transparent"
                    }`}
                  >
                    <input
                      ref={fileInputRef}
                      type="file"
                      className="hidden"
                      onChange={(e) => handleFile(e.target.files?.[0])}
                    />
                    <FileUp className="h-7 w-7 text-white mb-2" />
                    <p className="text-[9px] font-mono text-white font-bold leading-tight uppercase">
                      CLICK OR DRAG FILE HERE
                    </p>
                    <p className="text-[7px] font-mono text-brand-gray-light mt-1.5 uppercase">
                      Up to {Math.floor(FILE_MAX_BYTES / 1048576)}MB
                    </p>
                  </div>

                  {/* Expiry Choice */}
                  <div className="flex items-center justify-center gap-2 mt-4">
                    <span className="text-[7.5px] font-mono text-brand-gray-light uppercase tracking-wider">
                      Expires in:
                    </span>
                    {EXPIRY_CHOICES.map((c) => (
                      <button
                        key={c.hours}
                        onClick={() => setExpiryHours(c.hours)}
                        className={`px-2 py-0.5 text-[8px] font-bold tracking-widest border rounded transition-colors ${
                          expiryHours === c.hours
                            ? "border-white text-white bg-white/10"
                            : "border-white/10 text-brand-gray-light hover:text-white"
                        }`}
                      >
                        {c.label}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
