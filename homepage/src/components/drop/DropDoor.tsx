"use client";

import { useEffect, useState } from "react";
import {
  DROP_MAX_BYTES,
  DropError,
  FROM_MAX,
  NOTE_MAX,
  getDoor,
  parseHandle,
  sendDrop,
  type DoorState,
  type SendPhase,
} from "@/lib/dropApi";

type Phase = "loading" | "nohandle" | "closed" | "open" | "sending" | "sent" | "error";

const PHASE_TEXT: Record<SendPhase, string> = {
  sealing: "Sealing on this device…",
  uploading: "Uploading the sealed file…",
  finishing: "Finishing…",
};

function sizeLabel(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function DropDoor() {
  const [phase, setPhase] = useState<Phase>("loading");
  const [handle, setHandle] = useState("");
  const [door, setDoor] = useState<DoorState | null>(null);
  const [code, setCode] = useState("");
  const [from, setFrom] = useState("");
  const [note, setNote] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");

  async function look(h: string) {
    setPhase("loading");
    setError("");
    try {
      const next = await getDoor(h);
      setDoor(next);
      setPhase(next.open ? "open" : "closed");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not reach this address.");
      setPhase("error");
    }
  }

  useEffect(() => {
    const h = parseHandle(window.location);
    if (!h) {
      // The address comes from the URL, which only exists in the browser.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setPhase("nohandle");
      return;
    }
    setHandle(h);
    void look(h);
  }, []);

  async function send() {
    if (!door || !file) return;
    setError("");
    if (!from.trim()) {
      setError("Add your name so they know who it’s from.");
      return;
    }
    if (door.needsCode && !/^[0-9]{4,8}$/.test(code.trim())) {
      setError("Enter the door code they gave you.");
      return;
    }
    if (file.size > DROP_MAX_BYTES) {
      setError("That file is over 25 MB.");
      return;
    }
    setPhase("sending");
    try {
      await sendDrop({
        handle,
        code: code.trim(),
        file,
        from,
        note,
        shown: door.devices,
        onPhase: (p) => setStatus(PHASE_TEXT[p]),
      });
      setFile(null);
      setPhase("sent");
    } catch (e) {
      if (e instanceof DropError && e.code === "closed") {
        setPhase("closed");
        return;
      }
      setError(e instanceof Error ? e.message : "Couldn’t send.");
      setPhase("open");
    }
  }

  return (
    <main className="mx-auto flex min-h-full w-full max-w-xl flex-col gap-6 px-4 py-8">
      <header>
        <p className="text-sm text-brand-gray-light">NO SUS address</p>
        <h1 className="text-3xl font-semibold tracking-tight break-words">
          {handle ? `Send to ${handle}` : "Send a file"}
        </h1>
      </header>

      {phase === "loading" && <p className="text-base">Checking the door…</p>}

      {phase === "nohandle" && (
        <p className="text-base leading-relaxed">
          This link is missing an address. Ask for the full link, like nosus.foo/to?h=name.
        </p>
      )}

      {phase === "closed" && (
        <>
          <p className="text-base leading-relaxed">This door is closed. Ask them to open it.</p>
          <button
            type="button"
            onClick={() => void look(handle)}
            className="h-12 w-fit rounded-full bg-white px-5 font-semibold text-black"
          >
            Check again
          </button>
        </>
      )}

      {phase === "error" && (
        <>
          <p className="text-base leading-relaxed" role="alert">{error}</p>
          <button
            type="button"
            onClick={() => void look(handle)}
            className="h-12 w-fit rounded-full bg-white px-5 font-semibold text-black"
          >
            Try again
          </button>
        </>
      )}

      {(phase === "open" || phase === "sending") && door && (
        <form
          className="flex flex-col gap-4"
          onSubmit={(event) => {
            event.preventDefault();
            void send();
          }}
        >
          <p className="text-base leading-relaxed">
            The door is open. They’ll see your file only after they accept it.
          </p>

          {door.needsCode && (
            <label className="flex flex-col gap-1">
              <span className="text-sm">Door code</span>
              <input
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, "").slice(0, 8))}
                inputMode="numeric"
                autoComplete="off"
                className="h-12 rounded-xl border border-white/20 bg-transparent px-3 tracking-widest"
              />
            </label>
          )}

          <label className="flex flex-col gap-1">
            <span className="text-sm">File (up to 25 MB)</span>
            <input
              type="file"
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
              className="text-base file:mr-3 file:h-11 file:rounded-full file:border file:border-white/30 file:bg-transparent file:px-4 file:text-white"
            />
            {file && <span className="text-sm text-brand-gray-light">{file.name} · {sizeLabel(file.size)}</span>}
          </label>

          <label className="flex flex-col gap-1">
            <span className="text-sm">Your name</span>
            <input
              value={from}
              onChange={(e) => setFrom(e.target.value.slice(0, FROM_MAX))}
              maxLength={FROM_MAX}
              autoComplete="name"
              className="h-12 rounded-xl border border-white/20 bg-transparent px-3"
            />
          </label>

          <label className="flex flex-col gap-1">
            <span className="text-sm">Note (optional)</span>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value.slice(0, NOTE_MAX))}
              maxLength={NOTE_MAX}
              rows={3}
              className="rounded-xl border border-white/20 bg-transparent px-3 py-2"
            />
          </label>

          {error && <p className="text-base font-semibold" role="alert">{error}</p>}
          {phase === "sending" && <p className="text-base" aria-live="polite">{status}</p>}

          <button
            type="submit"
            disabled={phase === "sending" || !file}
            className="h-12 w-fit rounded-full bg-white px-5 font-semibold text-black disabled:opacity-50"
          >
            {phase === "sending" ? "Sending…" : "Send"}
          </button>

          <div className="flex flex-col gap-2 rounded-2xl border border-white/15 p-4 text-sm leading-relaxed">
            <p>
              Your browser seals the file, its name, your name, and your note to their devices before upload.
              Our server gets the sealed file, its size, when it was sent, and a hashed form of your network address
              (for rate limits and blocks).
            </p>
            {door.check && (
              <p>
                Door check: <span className="font-mono text-base tracking-wider">{door.check}</span>. If it matches
                the code on their phone, this page is sealing to their devices and not to a key swapped in on the
                way.
              </p>
            )}
            <p>Unaccepted files are deleted after 24 hours.</p>
          </div>
        </form>
      )}

      {phase === "sent" && (
        <>
          <p className="text-base leading-relaxed" aria-live="polite">Sent. They’ll see it after they accept.</p>
          <button
            type="button"
            onClick={() => {
              setNote("");
              setPhase("open");
            }}
            className="h-12 w-fit rounded-full border border-white/30 px-5"
          >
            Send another
          </button>
        </>
      )}
    </main>
  );
}
