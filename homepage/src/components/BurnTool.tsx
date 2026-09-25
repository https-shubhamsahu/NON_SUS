"use client";

import { useRef, useState, DragEvent, KeyboardEvent } from "react";
import {
  FileUp,
  Lock,
  Check,
  ClipboardPaste,
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
  warmBurnBackend,
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

const TABS: { id: Tab; label: string }[] = [
  { id: "note", label: "Note" },
  { id: "file", label: "File" },
  { id: "redeem", label: "Redeem" },
];

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
  const [pasteError, setPasteError] = useState("");
  const noteRef = useRef<HTMLTextAreaElement>(null);

  const pasteNote = async () => {
    setPasteError("");
    try {
      const clip = await navigator.clipboard.readText();
      const el = noteRef.current;
      const start = el?.selectionStart ?? noteText.length;
      const end = el?.selectionEnd ?? noteText.length;
      const next = (noteText.slice(0, start) + clip + noteText.slice(end)).slice(0, NOTE_MAX_CHARS);
      setNoteText(next);
      if (clip.length + noteText.length - (end - start) > NOTE_MAX_CHARS) {
        setPasteError(`Trimmed to ${NOTE_MAX_CHARS.toLocaleString()} characters.`);
      }
      requestAnimationFrame(() => el?.focus());
    } catch {
      setPasteError("Clipboard blocked. Long-press the box and paste.");
    }
  };
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
    setPasteError("");
  };

  // Intent (pointer, touch, focus, tab switch) warms exactly the edge
  // functions this tab is about to call — see warmBurnBackend.
  const warmFor = (t: Tab) =>
    warmBurnBackend(
      t === "file"
        ? ["burn-file-init", "burn-file-confirm", "create-redemption-code"]
        : t === "note"
          ? ["create-redemption-code"]
          : ["redeem-code"],
    );

  const switchTab = (next: Tab) => {
    setTab(next);
    reset();
    warmFor(next);
  };

  // WAI-ARIA tabs: arrow keys move between tabs (one Tab stop for the set).
  const onTabKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
    if (!step) return;
    e.preventDefault();
    const i = TABS.findIndex((t) => t.id === tab);
    const next = TABS[(i + step + TABS.length) % TABS.length].id;
    switchTab(next);
    document.getElementById(`burn-tab-${next}`)?.focus();
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
    <div
      className="relative mx-auto flex w-full items-center justify-center sm:w-fit"
      onPointerEnter={() => warmFor(tab)}
      onTouchStart={() => warmFor(tab)}
      onFocusCapture={() => warmFor(tab)}
    >
      <div
        className={`relative z-10 flex w-full flex-col items-center justify-center border-4 border-foreground/85 bg-card p-6 text-left shadow-[8px_8px_0_0_var(--muted)] transition-[border-radius,border-color] duration-200 ease-out motion-reduce:transition-none sm:w-[480px] xl:w-[520px] ${
          phase === "done"
            ? "min-h-[380px] rounded-[40px] py-8 sm:min-h-[480px] sm:rounded-[56px] xl:min-h-[520px]"
            : "min-h-[400px] rounded-[40px] sm:h-[480px] sm:rounded-full sm:px-14 xl:h-[520px]"
        } ${dragOver ? "border-foreground ring-4 ring-ring/30" : ""}`}
      >
          {phase === "working" ? (
            <div
              key="working"
              role="status"
              className="flex flex-col items-center justify-center gap-4 text-center"
            >
              <div className="relative">
                <div
                  className="w-16 h-16 border-2 border-dashed border-border rounded-full flex items-center justify-center animate-spin motion-reduce:animate-none"
                />
                <div className="absolute inset-0 flex items-center justify-center">
                  <Lock className="h-5 w-5 text-foreground" />
                </div>
              </div>
              <span className="text-xs font-mono tracking-widest text-muted-foreground animate-pulse motion-reduce:animate-none text-center max-w-[240px] uppercase">
                {statusLabel}
              </span>
            </div>
          ) : phase === "done" ? (
            <div
              key="done"
              role="status"
              className="flex flex-col items-center justify-center gap-4 text-center w-full px-2"
            >
              <div className="flex items-center gap-2 text-foreground">
                <Lock className="h-4 w-4 text-foreground" />
                <span className="text-xs font-bold tracking-widest uppercase">
                  READY TO SHARE
                </span>
              </div>

              <div className="flex flex-col items-center">
                <span className="text-xs font-bold tracking-[0.28em] uppercase text-muted-foreground">
                  Their code
                </span>
                {pairing ? (
                  <button
                    type="button"
                    onClick={copyCode}
                    aria-label={`Confirmation code ${pairing.code}`}
                    className="min-h-[44px] min-w-[44px] text-[52px] sm:text-[60px] leading-none font-black tabular-nums tracking-[0.18em] text-foreground"
                  >
                    {pairing.code}
                  </button>
                ) : !pairingSettled ? (
                  <span
                    className="text-[52px] sm:text-[60px] leading-none font-black tabular-nums tracking-[0.18em] text-muted-foreground/40 animate-pulse motion-reduce:animate-none"
                    aria-label="Generating confirmation code"
                  >
                    ··
                  </span>
                ) : (
                  <p className="mt-1 text-base text-muted-foreground max-w-[240px]">
                    Share the link. A pairing code was not issued for this drop.
                  </p>
                )}
                {pairing && (
                  <p className="text-sm text-muted-foreground">
                    {codeCopied ? "Code copied." : "Tap to copy. Tell them these digits."}
                  </p>
                )}
              </div>

              {sharedLink ? (
                <div className="p-2 bg-card border border-border rounded-[12px]">
                  <ShareQr value={sharedLink} size={108} />
                </div>
              ) : (
                <div
                  role="img"
                  aria-label="Preparing the share link"
                  className="w-[120px] h-[120px] rounded-[12px] bg-muted animate-pulse motion-reduce:animate-none"
                />
              )}

              <button
                type="button"
                onClick={copyLink}
                disabled={!sharedLink}
                className="btn btn-primary disabled:opacity-40 disabled:pointer-events-none"
              >
                {copied ? (
                  <>
                    <Check className="h-4 w-4" /> Copied
                  </>
                ) : (
                  <>
                    <Copy className="h-4 w-4" /> Copy Link
                  </>
                )}
              </button>
              {pairing && (
                <>
                  <p className="text-sm text-muted-foreground max-w-[280px]">
                    The link only opens with the code{pairingTimeLeft ? ` · works for ${pairingTimeLeft}` : ""}.
                  </p>
                  <button
                    type="button"
                    onClick={copyDirectLink}
                    className="btn btn-ghost text-sm"
                  >
                    {directCopied ? "Direct link copied" : "Copy direct link (no code)"}
                  </button>
                </>
              )}
              {copyError && <p className="text-base text-destructive" role="alert">{copyError}</p>}
              <button
                type="button"
                onClick={reset}
                className="btn btn-ghost text-sm"
              >
                <RotateCcw className="h-4 w-4" /> Burn another
              </button>
            </div>
          ) : phase === "error" ? (
            <div
              key="error"
              role="alert"
              className="flex flex-col items-center justify-center gap-4 text-center w-full p-4"
            >
              <AlertTriangle className="h-8 w-8 text-destructive" />
              <span className="text-base font-mono text-muted-foreground uppercase leading-relaxed max-w-[260px]">
                {error}
              </span>
              <button
                type="button"
                onClick={reset}
                className="btn btn-primary"
              >
                <RotateCcw className="h-4 w-4" /> Try again
              </button>
            </div>
          ) : (
            <div
              key="form"
              className="flex flex-col items-center justify-center w-full text-center relative z-20"
            >
              <div
                role="tablist"
                aria-label="Burn tool mode"
                onKeyDown={onTabKey}
                className="flex border border-border bg-muted/70 p-1 rounded-[10px] mb-4 w-full max-w-[320px]"
              >
                {TABS.map((t, i) => (
                  <button
                    key={t.id}
                    id={`burn-tab-${t.id}`}
                    type="button"
                    role="tab"
                    aria-selected={tab === t.id}
                    aria-controls="burn-panel"
                    tabIndex={tab === t.id ? 0 : -1}
                    onClick={() => switchTab(t.id)}
                    className={`flex-1 min-h-[44px] whitespace-nowrap px-2 sm:px-3 text-xs font-mono font-bold uppercase tracking-wider transition-colors duration-150 motion-reduce:transition-none rounded-[6px] ${
                      tab === t.id
                        ? "bg-card text-foreground shadow-sm border border-border/80"
                        : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <span className="hidden sm:inline">{`${String(i + 1).padStart(2, "0")} // `}</span>{t.label}
                  </button>
                ))}
              </div>

              <div id="burn-panel" role="tabpanel" aria-labelledby={`burn-tab-${tab}`} className="w-full">
              {tab === "note" ? (
                <div className="flex flex-col items-center w-full">
                  <textarea
                    ref={noteRef}
                    value={noteText}
                    onChange={(e) => {
                      setNoteText(e.target.value.slice(0, NOTE_MAX_CHARS));
                      setPasteError("");
                    }}
                    placeholder="Write or paste a secret note…"
                    aria-label="Secret note"
                    className="block w-full max-w-[360px] h-[128px] overflow-y-auto bg-background border border-border hover:border-foreground/40 focus:border-foreground p-4 text-base font-mono text-left text-foreground resize-none rounded-[12px] leading-relaxed"
                  />
                  <div className="flex flex-wrap items-center gap-2 w-full max-w-[360px] mt-3">
                    <button
                      type="button"
                      onClick={pasteNote}
                      className="min-h-[44px] flex items-center gap-2 px-4 rounded-[12px] border border-border text-sm font-bold uppercase tracking-wider text-foreground hover:bg-muted"
                    >
                      <ClipboardPaste className="h-4 w-4" aria-hidden="true" /> Paste
                    </button>
                    {noteText.length > 0 && (
                      <button
                        type="button"
                        onClick={() => {
                          setNoteText("");
                          setPasteError("");
                        }}
                        className="min-h-[44px] px-4 rounded-[12px] border border-border text-sm font-bold uppercase tracking-wider text-muted-foreground hover:text-foreground"
                      >
                        Clear
                      </button>
                    )}
                    {/* Notes always expire unread after 7 days (burn_notes.expires_at
                        default) — createBurnNote sends no expiry, so no picker here. */}
                    <span className="ml-auto font-mono text-xs text-muted-foreground">
                      {noteText.length.toLocaleString("en-US")}/{NOTE_MAX_CHARS.toLocaleString("en-US")}
                    </span>
                    {pasteError && <span className="w-full text-sm text-muted-foreground" role="alert">{pasteError}</span>}
                  </div>
                  <button
                    type="button"
                    onClick={handleCreateNote}
                    disabled={!noteText.trim()}
                    className={`btn mt-4 ${
                      noteText.trim()
                        ? "btn-primary"
                        : "opacity-40 cursor-not-allowed"
                    }`}
                  >
                    Burn Note
                  </button>
                </div>
              ) : tab === "file" ? (
                <div className="flex flex-col items-center w-full">
                  <div
                    onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                    onDragLeave={() => setDragOver(false)}
                    onDrop={handleDrop}
                    onClick={() => fileInputRef.current?.click()}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        fileInputRef.current?.click();
                      }
                    }}
                    role="button"
                    tabIndex={0}
                    className={`w-full max-w-[360px] min-h-[140px] border-2 border-dashed rounded-[12px] flex flex-col items-center justify-center cursor-pointer transition-colors duration-200 ease-out motion-reduce:transition-none p-6 ${
                      dragOver
                        ? "border-foreground bg-muted"
                        : "border-border hover:border-foreground/40 bg-transparent"
                    }`}
                  >
                    <input
                      ref={fileInputRef}
                      type="file"
                      className="hidden"
                      onChange={(e) => handleFile(e.target.files?.[0])}
                    />
                    <FileUp className="h-7 w-7 text-foreground mb-3" />
                    <p className="text-base font-mono text-foreground font-bold leading-tight uppercase">
                      Click or drag file here
                    </p>
                    <p className="text-sm font-mono text-muted-foreground mt-2 uppercase">
                      Up to {Math.floor(FILE_MAX_BYTES / 1048576)}MB
                    </p>
                  </div>

                  <div className="flex flex-wrap items-center justify-center gap-2 mt-4">
                    <span className="text-sm font-mono text-muted-foreground uppercase tracking-wider">
                      Expires in:
                    </span>
                    {EXPIRY_CHOICES.map((c) => (
                      <button
                        type="button"
                        key={c.hours}
                        onClick={() => setExpiryHours(c.hours)}
                        className={`min-h-[44px] px-3 text-sm font-bold tracking-widest border rounded-[12px] transition-colors duration-200 ease-out motion-reduce:transition-none ${
                          expiryHours === c.hours
                            ? "border-foreground text-foreground bg-muted"
                            : "border-border text-muted-foreground hover:text-foreground"
                        }`}
                      >
                        {c.label}
                      </button>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="flex flex-col items-center w-full">
                  <Key className="h-7 w-7 text-foreground mb-4" />
                  <input
                    type="text"
                    value={redeemInput}
                    onChange={(e) => setRedeemInput(e.target.value.slice(0, 200))}
                    onKeyDown={(e) => { if (e.key === "Enter") handleRedeem(); }}
                    placeholder="Paste the link"
                    autoCapitalize="characters"
                    autoCorrect="off"
                    spellCheck={false}
                    className="w-full max-w-[320px] min-h-[44px] bg-background border border-border hover:border-foreground/40 focus:border-foreground py-3 px-4 text-center text-base font-mono tracking-[0.2em] text-foreground rounded-[12px] uppercase"
                  />
                  <p className="text-sm font-mono text-muted-foreground mt-4 text-center max-w-[280px] leading-relaxed">
                    Paste the link you were sent. If it came with a 2-digit code, you&apos;ll type it next.
                  </p>
                  <button
                    type="button"
                    onClick={handleRedeem}
                    disabled={!redeemInput.trim()}
                    className={`btn mt-6 ${
                      redeemInput.trim()
                        ? "btn-primary"
                        : "opacity-40 cursor-not-allowed"
                    }`}
                  >
                    Unlock
                  </button>
                </div>
              )}
              </div>
            </div>
          )}
      </div>
    </div>
  );
}
