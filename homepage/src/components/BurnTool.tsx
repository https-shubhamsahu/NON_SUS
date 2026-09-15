"use client";

import { useRef, useState, DragEvent } from "react";
import {
  FileUp,
  Lock,
  Check,
  Copy,
  AlertTriangle,
  RotateCcw,
  Key,
} from "lucide-react";
import {
  appLinkFromPaste,
  createBurnFile,
  createBurnNote,
  linkToShare,
  redeemCode,
  FILE_MAX_BYTES,
  NOTE_MAX_CHARS,
  type RedemptionPairing,
} from "@/lib/burnApi";
import ShareQr from "./ShareQr";

type Tab = "note" | "file" | "redeem";
type Phase = "idle" | "working" | "done" | "error";

/** "20 min" / "3 hours" until an ISO time, or null if unknown or past. */
function timeLeft(expiresAt: string | null): string | null {
  if (!expiresAt) return null;
  const minutes = Math.round((Date.parse(expiresAt) - Date.now()) / 60000);
  if (!Number.isFinite(minutes) || minutes <= 0) return null;
  return minutes < 90 ? `${minutes} min` : `${Math.round(minutes / 60)} hours`;
}

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
  // Direct link (key in the fragment). What gets shared is linkToShare():
  // the pairing link when a code was issued, so the code is really needed.
  const [link, setLink] = useState("");
  const [pairing, setPairing] = useState<RedemptionPairing | null>(null);
  const [pairingTimeLeft, setPairingTimeLeft] = useState<string | null>(null);
  const [pairingSettled, setPairingSettled] = useState(false);
  const [copied, setCopied] = useState(false);
  const [directCopied, setDirectCopied] = useState(false);
  const [codeCopied, setCodeCopied] = useState(false);
  const [copyError, setCopyError] = useState("");
  const [noteText, setNoteText] = useState("");
  const [expiryHours, setExpiryHours] = useState(24);
  const [dragOver, setDragOver] = useState(false);
  const [redeemInput, setRedeemInput] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  // Bumped on every new create + on reset, so a slow redemption-code mint
  // from a previous (or abandoned) share can never overwrite the current one.
  const generationRef = useRef(0);

  const reset = () => {
    generationRef.current++;
    setPhase("idle");
    setError("");
    setLink("");
    setPairing(null);
    setPairingTimeLeft(null);
    setPairingSettled(false);
    setCopied(false);
    setDirectCopied(false);
    setCodeCopied(false);
    setCopyError("");
    setStatusLabel("");
    setRedeemInput("");
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
    if (!text || phase === "working") return;
    const generation = ++generationRef.current;
    setPhase("working");
    setStatusLabel("ENCRYPTING IN BROWSER…");
    try {
      const result = await createBurnNote(text);
      if (generationRef.current !== generation) return;
      setLink(result.link);
      setNoteText("");
      setPhase("done");
      result.pairingPromise.then((grant) => {
        if (generationRef.current !== generation) return;
        setPairing(grant);
        setPairingTimeLeft(timeLeft(grant?.expiresAt ?? null));
        setPairingSettled(true);
      });
    } catch (e) {
      if (generationRef.current === generation) fail(e);
    }
  };

  const handleFile = async (file: File | undefined | null) => {
    if (!file || phase === "working") return;
    const generation = ++generationRef.current;
    setPhase("working");
    try {
      const result = await createBurnFile(file, expiryHours, (p) => {
        if (generationRef.current !== generation) return;
        setStatusLabel(
          p.phase === "encrypting"
            ? "ENCRYPTING IN BROWSER…"
            : p.phase === "uploading"
              ? "UPLOADING CIPHERTEXT…"
              : "SEALING…",
        );
      });
      if (generationRef.current !== generation) return;
      setLink(result.link);
      setPhase("done");
      result.pairingPromise.then((grant) => {
        if (generationRef.current !== generation) return;
        setPairing(grant);
        setPairingTimeLeft(timeLeft(grant?.expiresAt ?? null));
        setPairingSettled(true);
      });
    } catch (e) {
      if (generationRef.current === generation) fail(e);
    }
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    handleFile(e.dataTransfer.files?.[0]);
  };

  const handleRedeem = async () => {
    if (phase === "working") return;
    const raw = redeemInput.trim();
    const target = appLinkFromPaste(raw);
    if (target) {
      window.location.href = target;
      return;
    }
    if (/^\d{2}$/.test(raw)) {
      setError("Paste the link first. You'll type the 2 digits after it opens.");
      setPhase("error");
      return;
    }
    setPhase("working");
    setStatusLabel("LOOKING UP CODE…");
    try {
      const url = await redeemCode(raw);
      setStatusLabel("UNLOCKED · OPENING…");
      window.location.href = url;
    } catch (e) {
      fail(e);
    }
  };

  // Empty until pairing settles, so nobody copies a link that skips the code.
  const sharedLink = pairingSettled ? linkToShare(link, pairing) : "";

  const copyLink = async () => {
    if (!sharedLink) return;
    try {
      await navigator.clipboard.writeText(sharedLink);
      setCopyError("");
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopyError("Clipboard blocked. Scan the QR from another device instead.");
    }
  };

  const copyDirectLink = async () => {
    try {
      await navigator.clipboard.writeText(link);
      setCopyError("");
      setDirectCopied(true);
      setTimeout(() => setDirectCopied(false), 2000);
    } catch {
      setCopyError("Clipboard blocked. Scan the QR from another device instead.");
    }
  };

  const copyCode = async () => {
    if (!pairing) return;
    try {
      await navigator.clipboard.writeText(pairing.code);
      setCopyError("");
      setCodeCopied(true);
      setTimeout(() => setCodeCopied(false), 2000);
    } catch {
      setCopyError("Clipboard unavailable. Copy the code by hand.");
    }
  };

  return (
    <div className="relative flex flex-col items-center justify-center py-6">
      {/* Keep the branded circle without continuous animation work. */}
      <div
        className={`relative z-10 w-[min(380px,calc(100vw-32px))] sm:w-[440px] border-4 border-white/80 bg-brand-black/95 text-left flex flex-col items-center justify-center p-6 shadow-[8px_8px_0px_0px_rgba(255,255,255,0.05)] transition-colors ${
          phase === "done"
            ? "h-auto min-h-[380px] sm:min-h-[440px] py-8 rounded-[48px] sm:rounded-[56px]"
            : "h-[380px] sm:h-[440px] rounded-[50%]"
        } ${dragOver ? "scale-105 border-white bg-white/5" : ""}`}
      >
          {phase === "working" ? (
            <div
              key="working"
              role="status"
              className="flex flex-col items-center justify-center gap-4 text-center"
            >
              <div className="relative">
                <div
                  className="w-16 h-16 border-2 border-dashed border-white rounded-full flex items-center justify-center animate-spin motion-reduce:animate-none"
                />
                <div className="absolute inset-0 flex items-center justify-center">
                  <Lock className="h-5 w-5 text-white" />
                </div>
              </div>
              <span className="text-[10px] font-mono tracking-widest text-brand-gray-light animate-pulse text-center max-w-[200px] uppercase">
                {statusLabel}
              </span>
            </div>
          ) : phase === "done" ? (
            <div
              key="done"
              role="status"
              className="flex flex-col items-center justify-center gap-2 text-center w-full px-3"
            >
              <div className="flex items-center gap-2 text-white">
                <Lock className="h-4 w-4 text-green-400" />
                <span className="text-[10px] font-bold tracking-widest uppercase">
                  READY TO SHARE
                </span>
              </div>

              <div className="flex flex-col items-center">
                <span className="text-[9px] font-bold tracking-[0.28em] uppercase text-brand-gray-light">
                  Their code
                </span>
                {pairing ? (
                  <button
                    type="button"
                    onClick={copyCode}
                    aria-label={`Confirmation code ${pairing.code}`}
                    className="text-[52px] sm:text-[60px] leading-none font-black tabular-nums tracking-[0.18em] text-white"
                  >
                    {pairing.code}
                  </button>
                ) : !pairingSettled ? (
                  <span
                    className="text-[52px] sm:text-[60px] leading-none font-black tabular-nums tracking-[0.18em] text-white/25 animate-pulse"
                    aria-label="Generating confirmation code"
                  >
                    ··
                  </span>
                ) : (
                  <p className="mt-1 text-[10px] text-brand-gray-light max-w-[200px]">
                    Share the link. A pairing code was not issued for this drop.
                  </p>
                )}
                {pairing && (
                  <p className="text-[8px] text-brand-gray-light">
                    {codeCopied ? "Code copied." : "Tap to copy. Tell them these digits."}
                  </p>
                )}
              </div>

              {sharedLink ? (
                <div className="p-1.5 bg-white rounded-lg">
                  <ShareQr value={sharedLink} size={108} />
                </div>
              ) : (
                <div
                  role="img"
                  aria-label="Preparing the share link"
                  className="w-[120px] h-[120px] rounded-lg bg-white/10 animate-pulse motion-reduce:animate-none"
                />
              )}

              <button
                onClick={copyLink}
                disabled={!sharedLink}
                className="bg-white text-black px-6 py-2 text-[9px] font-bold uppercase tracking-widest hover:bg-black hover:text-white border border-white transition-all rounded-full flex items-center gap-2 z-20 disabled:opacity-40 disabled:pointer-events-none"
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
              {pairing && (
                <>
                  <p className="text-[8px] text-brand-gray-light max-w-[240px]">
                    The link only opens with the code{pairingTimeLeft ? ` · works for ${pairingTimeLeft}` : ""}.
                  </p>
                  <button
                    onClick={copyDirectLink}
                    className="text-[8px] font-bold uppercase tracking-widest text-brand-gray-light underline underline-offset-2 hover:text-white transition-colors z-20"
                  >
                    {directCopied ? "Direct link copied" : "Copy direct link (no code)"}
                  </button>
                </>
              )}
              {copyError && <p className="text-[10px] text-brand-gray-light" role="alert">{copyError}</p>}
              <button
                onClick={reset}
                className="inline-flex items-center gap-1.5 text-[9px] font-bold uppercase tracking-widest text-brand-gray-light hover:text-white transition-colors z-20"
              >
                <RotateCcw className="h-3 w-3" /> Burn another
              </button>
            </div>
          ) : phase === "error" ? (
            <div
              key="error"
              role="alert"
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
            </div>
          ) : (
            <div
              key="form"
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
                <button
                  onClick={() => switchTab("redeem")}
                  className={`px-4 py-1.5 text-[9px] font-bold uppercase tracking-wider transition-colors ${
                    tab === "redeem" ? "bg-white text-black" : "text-brand-gray-light hover:text-white"
                  }`}
                >
                  Redeem
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
              ) : tab === "file" ? (
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
              ) : (
                <div className="flex flex-col items-center w-full">
                  <Key className="h-7 w-7 text-white mb-3" />
                  <input
                    type="text"
                    value={redeemInput}
                    onChange={(e) => setRedeemInput(e.target.value.slice(0, 200))}
                    onKeyDown={(e) => { if (e.key === "Enter") handleRedeem(); }}
                    placeholder="Paste the link"
                    autoCapitalize="characters"
                    autoCorrect="off"
                    spellCheck={false}
                    className="w-[70%] bg-brand-black/50 border border-white/10 hover:border-white/30 focus:border-white focus:outline-none py-3 text-center text-lg font-mono tracking-[0.35em] text-white rounded-xl uppercase"
                  />
                  <p className="text-[7.5px] font-mono text-brand-gray-light mt-3 uppercase text-center max-w-[220px] leading-relaxed">
                    Paste the link you were sent. If it came with a 2-digit code, you&apos;ll type it next.
                  </p>
                  <button
                    onClick={handleRedeem}
                    disabled={!redeemInput.trim()}
                    className={`mt-5 px-6 py-2.5 text-[9px] font-bold uppercase tracking-widest rounded-full border transition-all ${
                      redeemInput.trim()
                        ? "bg-white text-black border-white hover:bg-black hover:text-white active:scale-95"
                        : "bg-transparent text-white/30 border-white/10 cursor-not-allowed"
                    }`}
                  >
                    Unlock
                  </button>
                </div>
              )}
            </div>
          )}
      </div>
    </div>
  );
}
