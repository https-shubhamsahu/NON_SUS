"use client";

import { useRef, useState, DragEvent } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Flame,
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

type Tab = "note" | "file";
type Phase = "idle" | "working" | "done" | "error";

const EXPIRY_CHOICES = [
  { hours: 1, label: "1 HOUR" },
  { hours: 24, label: "24 HOURS" },
  { hours: 168, label: "7 DAYS" },
];

/**
 * The real thing, not a mockup: creates actual one-time Burn Notes and Burn
 * Files against the production backend, with the same client-side encryption
 * the app uses (see lib/burnCrypto.ts). The link's key/IV never leave the
 * visitor's browser.
 */
export default function BurnTool() {
  const [tab, setTab] = useState<Tab>("note");
  const [phase, setPhase] = useState<Phase>("idle");
  const [statusLabel, setStatusLabel] = useState("");
  const [error, setError] = useState("");
  const [link, setLink] = useState("");
  const [copied, setCopied] = useState(false);
  const [noteText, setNoteText] = useState("");
  const [expiryHours, setExpiryHours] = useState(24);
  const [dragOver, setDragOver] = useState(false);
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
    setStatusLabel("ENCRYPTING IN YOUR BROWSER…");
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
            ? "ENCRYPTING IN YOUR BROWSER…"
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
    <div className="w-full max-w-2xl mx-auto border border-brand-gray bg-brand-gray-dark/40 rounded overflow-hidden paper-card text-left">
      {/* Tabs */}
      <div className="flex border-b border-brand-gray bg-brand-black/40">
        {(
          [
            { id: "note", name: "Burn Note", icon: Flame },
            { id: "file", name: "Burn File", icon: FileUp },
          ] as const
        ).map((t) => (
          <button
            key={t.id}
            onClick={() => switchTab(t.id)}
            className={`flex items-center gap-2 px-6 py-4 text-[10px] font-bold uppercase tracking-widest transition-colors border-r border-brand-gray focus:outline-none ${
              tab === t.id
                ? "bg-brand-gray-dark text-white border-b-2 border-b-white"
                : "text-brand-gray-light hover:text-white"
            }`}
          >
            <t.icon className="h-3.5 w-3.5" />
            {t.name}
          </button>
        ))}
        <div className="flex-1 flex items-center justify-end pr-4">
          <span className="text-[9px] font-mono text-brand-gray-light uppercase tracking-wider hidden sm:block">
            Real · Anonymous · One-Time
          </span>
        </div>
      </div>

      <div className="p-6">
        {/* No mode="wait": the incoming state must mount immediately. If a
            user backgrounds the tab mid-mint, a queued exit animation must
            never strand them on the old view while the link is already ready. */}
        <AnimatePresence>
          {phase === "done" ? (
            <motion.div
              key="done"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="flex flex-col gap-4"
            >
              <div className="flex items-center gap-2 text-white">
                <Lock className="h-4 w-4" />
                <span className="text-xs font-bold tracking-widest uppercase">
                  One-time link minted
                </span>
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  readOnly
                  value={link}
                  onFocus={(e) => e.target.select()}
                  className="flex-1 bg-brand-black border border-brand-gray px-4 py-2.5 text-[11px] font-mono text-brand-gray-light rounded min-w-0"
                />
                <button
                  onClick={copyLink}
                  className="bg-white text-black px-4 flex items-center justify-center hover:bg-white/80 active:scale-95 transition-all rounded"
                  aria-label="Copy one-time link"
                >
                  {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                </button>
              </div>
              <p className="text-[10px] text-brand-gray-light leading-relaxed">
                The decryption key lives only in this link (after the “#”) — it was
                never sent to any server, and we cannot recover it or the content.
                The {tab === "note" ? "note" : "file"} destroys itself the first
                time the link is opened.
              </p>
              <button
                onClick={reset}
                className="inline-flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-widest text-brand-gray-light hover:text-white transition-colors self-start"
              >
                <RotateCcw className="h-3 w-3" /> Create another
              </button>
            </motion.div>
          ) : tab === "note" ? (
            <motion.div
              key="note"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="flex flex-col gap-4"
            >
              <textarea
                value={noteText}
                onChange={(e) => setNoteText(e.target.value.slice(0, NOTE_MAX_CHARS))}
                placeholder="Type a secret note. It self-destructs the first time it is read."
                rows={4}
                disabled={phase === "working"}
                className="w-full bg-brand-black border border-brand-gray focus:border-white transition-colors rounded p-4 text-xs text-white placeholder:text-brand-gray-light/60 font-medium resize-none focus:outline-none"
              />
              <div className="flex items-center justify-between gap-4">
                <span className="text-[9px] font-mono text-brand-gray-light">
                  {noteText.length}/{NOTE_MAX_CHARS} · AES-256 in your browser
                </span>
                <button
                  onClick={handleCreateNote}
                  disabled={phase === "working" || !noteText.trim()}
                  className="flex items-center gap-2 bg-white text-black px-6 py-2.5 text-[10px] font-bold uppercase tracking-widest border border-white transition-all hover:bg-black hover:text-white disabled:opacity-40 disabled:pointer-events-none rounded-sm"
                >
                  <Flame className="h-3.5 w-3.5" />
                  {phase === "working" ? statusLabel : "Mint one-time link"}
                </button>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key="file"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              className="flex flex-col gap-4"
            >
              <div
                onDragOver={(e) => {
                  e.preventDefault();
                  setDragOver(true);
                }}
                onDragLeave={() => setDragOver(false)}
                onDrop={handleDrop}
                onClick={() => phase !== "working" && fileInputRef.current?.click()}
                className={`border-2 border-dashed rounded p-8 flex flex-col items-center justify-center gap-2 cursor-pointer transition-all ${
                  dragOver
                    ? "border-white bg-white/5 scale-[1.01]"
                    : "border-brand-gray hover:border-white/60 bg-brand-black/40"
                }`}
              >
                <input
                  ref={fileInputRef}
                  type="file"
                  className="hidden"
                  onChange={(e) => handleFile(e.target.files?.[0])}
                />
                <FileUp className="h-7 w-7 text-brand-gray-light" />
                <span className="text-[10px] font-bold uppercase tracking-widest text-white">
                  {phase === "working" ? statusLabel : "Drop a file or click to browse"}
                </span>
                <span className="text-[9px] font-mono text-brand-gray-light">
                  Up to {Math.floor(FILE_MAX_BYTES / 1048576)}MB · encrypted before it leaves this tab
                </span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-[9px] font-mono text-brand-gray-light uppercase tracking-wider">
                  Unclaimed link expires in
                </span>
                {EXPIRY_CHOICES.map((c) => (
                  <button
                    key={c.hours}
                    onClick={() => setExpiryHours(c.hours)}
                    disabled={phase === "working"}
                    className={`px-2.5 py-1 text-[9px] font-bold tracking-widest border rounded-sm transition-colors ${
                      expiryHours === c.hours
                        ? "border-white text-white bg-white/10"
                        : "border-brand-gray text-brand-gray-light hover:text-white"
                    }`}
                  >
                    {c.label}
                  </button>
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {phase === "error" && (
          <div className="mt-4 flex items-start gap-2 border border-brand-gray bg-brand-black/60 rounded p-3">
            <AlertTriangle className="h-4 w-4 text-white shrink-0 mt-0.5" />
            <div className="flex flex-col gap-1">
              <span className="text-[10px] text-brand-gray-light leading-relaxed">{error}</span>
              <button
                onClick={reset}
                className="text-[9px] font-bold uppercase tracking-widest text-white hover:text-brand-gray-light self-start"
              >
                Try again
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
