"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import QRCode from "qrcode";
import { RealtimeClient, type RealtimeChannel } from "@supabase/realtime-js";
import { b64url, generateGoKeyPair, randomBytes } from "@/lib/nosusSeal";
import { DeskMachine, deviceLabel, parseGrant, sessionOver, type GoGrant } from "@/lib/goMachine";
import { downloadSealed, openGoSession, uploadSealed } from "@/lib/goTransfer";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "@/lib/links";

type Phase = "qr" | "code" | "chat" | "ended" | "error";

type Row = {
  id: string;
  name: string;
  mime: string;
  size: number;
  text?: string;
  src: string;
  status: string;
  blob?: Blob;
  preview?: string;
};

const QR_MS = 120_000;
const VERIFY_MS = 60_000;

export default function GoDesk() {
  const [phase, setPhase] = useState<Phase>("qr");
  const [qr, setQr] = useState("");
  const [code, setCode] = useState("");
  const [note, setNote] = useState("Scan with the NO SUS app. Your Google account stays on your phone.");
  const [scope, setScope] = useState("");
  const [rows, setRows] = useState<Row[]>([]);
  const [text, setText] = useState("");
  const [left, setLeft] = useState("");
  const [background, setBackground] = useState(false);
  const [canSend, setCanSend] = useState(false);

  const machine = useRef<DeskMachine | null>(null);
  const channel = useRef<RealtimeChannel | null>(null);
  const client = useRef<RealtimeClient | null>(null);
  const grant = useRef<GoGrant | null>(null);
  const lastInput = useRef(0);
  const ended = useRef(false);
  const rotateTimer = useRef<number | null>(null);
  const verifyTimer = useRef<number | null>(null);
  const pending = useRef<Map<string, Record<string, unknown>>>(new Map());

  const clearTimers = () => {
    if (rotateTimer.current) window.clearTimeout(rotateTimer.current);
    if (verifyTimer.current) window.clearTimeout(verifyTimer.current);
    rotateTimer.current = null;
    verifyTimer.current = null;
  };

  const leave = useCallback(async () => {
    clearTimers();
    const current = channel.current;
    channel.current = null;
    if (current) await current.unsubscribe();
    client.current?.disconnect();
    client.current = null;
  }, []);

  const wipe = useCallback(async (next: Phase, message: string) => {
    if (ended.current && next !== "qr") return;
    ended.current = next !== "qr";
    machine.current = null;
    grant.current = null;
    pending.current.clear();
    await leave();
    setRows([]);
    setPhase(next);
    setNote(message);
  }, [leave]);

  const send = useCallback(async (wire: Record<string, unknown>) => {
    const current = channel.current;
    if (!current) return;
    await current.send({ type: "broadcast", event: "e", payload: wire });
  }, []);

  const onWire = useCallback(async (wire: Record<string, unknown>) => {
    const desk = machine.current;
    if (!desk || ended.current) return;
    const incoming = await desk.receive(wire);
    if (desk.aborted) {
      const competing = desk.abortReason === "competing";
      await wipe(
        "error",
        competing
          ? "Someone else scanned this code. Refresh to make a new one."
          : "This session stopped. Refresh and scan again.",
      );
      return;
    }
    for (const again of incoming.resend) await send(again);
    if (incoming.hello && desk.matchCode != null) {
      if (rotateTimer.current) window.clearTimeout(rotateTimer.current);
      rotateTimer.current = null;
      setCode(String(desk.matchCode).padStart(2, "0"));
      setPhase("code");
      setNote("Match this code on your phone. It stops changing now.");
      const welcome = await desk.sendEvent({
        t: "welcome",
        dev: deviceLabel(navigator.userAgent),
      });
      await send(welcome);
      if (verifyTimer.current) window.clearTimeout(verifyTimer.current);
      verifyTimer.current = window.setTimeout(() => {
        void wipe("error", "That code expired. Refresh and scan the new one.");
      }, VERIFY_MS);
      return;
    }
    const event = incoming.event;
    if (!event || incoming.seq == null) return;
    lastInput.current = Math.floor(Date.now() / 1000);
    if (event.t === "grant") {
      const parsed = parseGrant(event);
      if (!parsed) return;
      if (verifyTimer.current) window.clearTimeout(verifyTimer.current);
      grant.current = parsed;
      const ack = await desk.sendEvent({ t: "ack" });
      desk.remember(incoming.seq, ack);
      await send(ack);
      setCanSend(parsed.mode !== "receive");
      setScope(
        `${parsed.whole ? "Whole Saved chat" : `${parsed.ids.length} items`} · ${
          parsed.mode === "both" ? "receive and send" : parsed.mode === "send" ? "send only" : "receive only"
        }`,
      );
      setPhase("chat");
      setNote("Your Google account stays on your phone. Anything you download or print may stay on this computer.");
      return;
    }
    if (event.t === "list" && Array.isArray(event.items)) {
      const next: Row[] = [];
      for (const raw of event.items) {
        if (!raw || typeof raw !== "object") continue;
        const item = raw as Record<string, unknown>;
        if (typeof item.id !== "string") continue;
        next.push({
          id: item.id,
          name: typeof item.name === "string" ? item.name : "Item",
          mime: typeof item.mime === "string" ? item.mime : "",
          size: typeof item.size === "number" ? item.size : 0,
          text: typeof item.text === "string" ? item.text : undefined,
          src: typeof item.src === "string" ? item.src : "phone",
          status: item.text ? "On your phone" : "Tap to open",
        });
      }
      setRows(next);
      return;
    }
    if (event.t === "item" && typeof event.id === "string") {
      const id = event.id;
      setRows((current) => current.map((row) => (row.id === id ? { ...row, status: "Getting…" } : row)));
      try {
        if (typeof event.fileId !== "string" || typeof event.key !== "string" || typeof event.nonce !== "string") {
          throw new Error("missing");
        }
        const bytes = await downloadSealed(event.fileId, event.key, event.nonce);
        const raw = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
        const blob = new Blob([raw], {
          type: typeof event.mime === "string" ? event.mime : "application/octet-stream",
        });
        const preview = blob.type.startsWith("image/") ? URL.createObjectURL(blob) : undefined;
        setRows((current) => current.map((row) => (row.id === id ? { ...row, status: "Ready", blob, preview } : row)));
      } catch {
        setRows((current) => current.map((row) => (row.id === id ? { ...row, status: "Couldn't get it · Retry" } : row)));
      }
      return;
    }
    if (event.t === "saw" && typeof event.id === "string") {
      pending.current.delete(event.id);
      setRows((current) => current.map((row) => (row.id === event.id ? { ...row, status: "On your phone" } : row)));
    }
    if (event.t === "end") {
      await wipe("ended", "Session ended. This computer can’t request anything else. Copies you already saved may remain.");
    }
  }, [send, wipe]);

  const beginRef = useRef<() => Promise<void>>(async () => {});

  const begin = useCallback(async () => {
    ended.current = false;
    clearTimers();
    await leave();
    const pair = await generateGoKeyPair();
    const sid = b64url(randomBytes(16));
    const desk = new DeskMachine(sid, pair.privateKey, pair.publicKey);
    machine.current = desk;
    setPhase("qr");
    setCode("");
    setRows([]);
    setNote("Scan with the NO SUS app. Your Google account stays on your phone.");
    try {
      await openGoSession(sid);
    } catch (error) {
      setPhase("error");
      setNote(error instanceof Error ? error.message : "Could not open a session.");
      return;
    }
    const url = `https://app.nosus.foo/#/go/1.${sid}.${b64url(pair.publicKey)}`;
    setQr(await QRCode.toDataURL(url, { margin: 1, width: 280, errorCorrectionLevel: "M" }));
    const realtime = new RealtimeClient(`${SUPABASE_URL}/realtime/v1`, {
      params: { apikey: SUPABASE_ANON_KEY },
    });
    await realtime.setAuth(SUPABASE_ANON_KEY);
    client.current = realtime;
    const topic = realtime.channel(`go:${sid}`, {
      config: { private: true, broadcast: { self: false } },
    });
    topic.on("broadcast", { event: "e" }, (message: { payload?: Record<string, unknown> }) => {
      const payload = message.payload;
      if (payload) void onWire(payload);
    });
    topic.subscribe();
    channel.current = topic;
    rotateTimer.current = window.setTimeout(() => {
      void beginRef.current();
    }, QR_MS);
  }, [leave, onWire]);

  useEffect(() => {
    beginRef.current = begin;
    // Mount starts the external session. The QR is that session, not derived state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    void begin();
    const onHide = (event: PageTransitionEvent) => {
      if (event.persisted) return;
      const desk = machine.current;
      if (desk?.keys && !ended.current) {
        void desk.sendEvent({ t: "end" }).then((wire) => send(wire)).finally(() => {
          void wipe("ended", "Session ended because this page closed.");
        });
      }
    };
    const onShow = (event: PageTransitionEvent) => {
      if (event.persisted && ended.current) void begin();
    };
    const onVisible = () => setBackground(document.hidden);
    window.addEventListener("pagehide", onHide);
    window.addEventListener("pageshow", onShow);
    document.addEventListener("visibilitychange", onVisible);
    const clock = window.setInterval(() => {
      const current = grant.current;
      if (!current || ended.current) return;
      const now = Math.floor(Date.now() / 1000);
      const remain = Math.max(0, current.exp - now);
      const min = Math.floor(remain / 60);
      const sec = remain % 60;
      setLeft(`${min}:${String(sec).padStart(2, "0")}`);
      if (sessionOver(now, current.exp, lastInput.current || now, current.idle)) {
        void wipe("ended", "Session ended. Copies you already saved may remain.");
      }
    }, 1000);
    return () => {
      window.removeEventListener("pagehide", onHide);
      window.removeEventListener("pageshow", onShow);
      document.removeEventListener("visibilitychange", onVisible);
      window.clearInterval(clock);
      void leave();
    };
  }, [begin, leave, send, wipe]);

  async function endSession() {
    const desk = machine.current;
    if (desk?.keys) {
      try {
        await send(await desk.sendEvent({ t: "end" }));
      } catch {
        // The row expires anyway.
      }
    }
    await wipe("ended", "Session ended. Anything you downloaded or printed may stay on this computer.");
  }

  async function sendText() {
    const desk = machine.current;
    const body = text.trim();
    if (!desk || !canSend || !body) return;
    const id = crypto.randomUUID();
    const row: Row = { id, name: body, mime: "text/markdown", size: body.length, text: body, src: "computer", status: "Saving…" };
    setRows((current) => [...current, row]);
    setText("");
    lastInput.current = Math.floor(Date.now() / 1000);
    const wire = await desk.sendEvent({ t: "msg", id, text: body, src: "computer" });
    pending.current.set(id, wire);
    await send(wire);
  }

  async function sendFile(file: File) {
    const desk = machine.current;
    if (!desk || !canSend) return;
    if (file.size > 25 * 1024 * 1024) {
      setNote("That file is over 25 MB.");
      return;
    }
    const id = crypto.randomUUID();
    setRows((current) => [
      ...current,
      { id, name: file.name, mime: file.type || "application/octet-stream", size: file.size, src: "computer", status: "Saving…" },
    ]);
    lastInput.current = Math.floor(Date.now() / 1000);
    try {
      const transit = await uploadSealed(new Uint8Array(await file.arrayBuffer()));
      const wire = await desk.sendEvent({
        t: "item",
        id,
        fileId: transit.fileId,
        key: transit.key,
        nonce: transit.nonce,
        name: file.name,
        mime: file.type || "application/octet-stream",
        size: file.size,
      });
      pending.current.set(id, wire);
      await send(wire);
    } catch (error) {
      setRows((current) =>
        current.map((row) => (row.id === id ? { ...row, status: "Couldn't send · Retry" } : row)),
      );
      setNote(error instanceof Error ? error.message : "Couldn't send.");
    }
  }

  async function openItem(row: Row) {
    const desk = machine.current;
    if (!desk || row.blob || row.text) return;
    setRows((current) => current.map((item) => (item.id === row.id ? { ...item, status: "Getting…" } : item)));
    await send(await desk.sendEvent({ t: "want", id: row.id }));
  }

  function download(row: Row) {
    if (!row.blob) return;
    const url = URL.createObjectURL(row.blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = row.name;
    link.click();
    URL.revokeObjectURL(url);
  }

  function printRow(row: Row) {
    if (!row.blob) return;
    const url = URL.createObjectURL(row.blob);
    const frame = document.createElement("iframe");
    frame.setAttribute("title", row.name);
    frame.style.position = "fixed";
    frame.style.width = "0";
    frame.style.height = "0";
    frame.style.border = "0";
    frame.src = url;
    frame.onload = () => frame.contentWindow?.print();
    document.body.appendChild(frame);
  }

  return (
    <main className="mx-auto flex min-h-full w-full max-w-xl flex-col gap-6 px-4 py-8">
      <header>
        <p className="text-sm text-brand-gray-light">Saved · only you</p>
        <h1 className="text-3xl font-semibold tracking-tight">Open on this computer</h1>
      </header>
      <p className="text-base leading-relaxed">{note}</p>
      {background && phase === "chat" && (
        <p className="text-sm">This tab is in the background. The session stays open.</p>
      )}
      {phase === "qr" && qr && (
        // Data-URL QR. next/image does not optimize these.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={qr} alt="QR code to scan with the NO SUS app" width={280} height={280} className="bg-white p-2" />
      )}
      {phase === "code" && (
        <p className="text-6xl font-semibold tracking-widest" aria-live="polite">{code}</p>
      )}
      {phase === "chat" && (
        <>
          <div className="flex flex-wrap items-center gap-3">
            <button type="button" onClick={() => void endSession()} className="h-12 rounded-full bg-white px-5 font-semibold text-black">
              End session
            </button>
            <span>{left}</span>
            <span>{scope}</span>
          </div>
          <ul className="flex flex-col gap-3">
            {rows.map((row) => (
              <li key={row.id} className="rounded-2xl border border-white/15 p-4">
                <p className="text-base">{row.text ?? `${row.name} · ${row.size} bytes`}</p>
                <p className="text-sm text-brand-gray-light">{row.src === "computer" ? "From computer" : "From phone"} · {row.status}</p>
                {!row.text && (
                  <div className="mt-3 flex flex-wrap gap-2">
                    <button type="button" className="h-11 rounded-full border border-white/30 px-4" onClick={() => {
                      lastInput.current = Math.floor(Date.now() / 1000);
                      void openItem(row);
                    }}>
                      Open
                    </button>
                    <button type="button" className="h-11 rounded-full border border-white/30 px-4" onClick={() => download(row)} disabled={!row.blob}>
                      Download
                    </button>
                    <button type="button" className="h-11 rounded-full border border-white/30 px-4" onClick={() => printRow(row)} disabled={!row.blob}>
                      Print
                    </button>
                  </div>
                )}
                {row.preview && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img alt={row.name} className="mt-3 max-h-64" src={row.preview} />
                )}
              </li>
            ))}
          </ul>
          {canSend && (
            <form
              className="flex gap-2"
              onSubmit={(event) => {
                event.preventDefault();
                void sendText();
              }}
            >
              <input
                value={text}
                onChange={(event) => setText(event.target.value)}
                placeholder="Note or link"
                className="h-12 flex-1 rounded-xl border border-white/20 bg-transparent px-3"
              />
              <button type="submit" className="h-12 rounded-full bg-white px-5 font-semibold text-black">Send</button>
              <label className="flex h-12 cursor-pointer items-center rounded-full border border-white/30 px-4">
                Attach
                <input
                  type="file"
                  className="sr-only"
                  onChange={(event) => {
                    const file = event.target.files?.[0];
                    if (file) void sendFile(file);
                    event.target.value = "";
                  }}
                />
              </label>
            </form>
          )}
        </>
      )}
      {(phase === "ended" || phase === "error") && (
        <button type="button" onClick={() => void begin()} className="h-12 w-fit rounded-full bg-white px-5 font-semibold text-black">
          New code
        </button>
      )}
    </main>
  );
}
