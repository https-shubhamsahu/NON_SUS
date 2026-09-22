// Desk half of the phone's GoMachine (lib/features/address/go_session.dart).
// Hello is the only plaintext event. The first phone key locks the session.

import {
  b64url,
  b64urlDecode,
  deriveGoKeys,
  openJson,
  sealJson,
  sharedSecret,
  type GoKeyMaterial,
} from "./nosusSeal";

export type GoRecv = {
  hello: boolean;
  event?: Record<string, unknown>;
  seq?: number;
  resend: Record<string, unknown>[];
};

export type GoGrant = {
  whole: boolean;
  ids: string[];
  mode: "send" | "receive" | "both";
  exp: number;
  idle: number;
};

export function parseGrant(event: Record<string, unknown>): GoGrant | null {
  if (event.t !== "grant") return null;
  const scope = event.scope;
  const mode = event.mode;
  const exp = typeof event.exp === "number" ? event.exp : NaN;
  if ((scope !== "items" && scope !== "all") || !Number.isFinite(exp) || exp <= 0) return null;
  if (mode !== "send" && mode !== "receive" && mode !== "both") return null;
  const ids: string[] = [];
  if (scope === "items") {
    if (!Array.isArray(event.ids) || event.ids.length === 0) return null;
    for (const id of event.ids) {
      if (typeof id !== "string" || id.length === 0) return null;
      ids.push(id);
    }
  }
  const idle = typeof event.idle === "number" && event.idle > 0 ? event.idle : 600;
  return { whole: scope === "all", ids, mode, exp, idle };
}

export function sessionOver(nowSec: number, exp: number, lastInputSec: number, idleSec: number): boolean {
  return nowSec >= exp || nowSec - lastInputSec >= idleSec;
}

export function deviceLabel(ua: string): string {
  const os = /Windows/.test(ua)
    ? "Windows"
    : /Mac OS|Macintosh/.test(ua)
      ? "Mac"
      : /Android/.test(ua)
        ? "Android"
        : /iPhone|iPad/.test(ua)
          ? "iPhone"
          : "this computer";
  const browser = /Edg\//.test(ua) ? "Edge" : /Firefox\//.test(ua) ? "Firefox" : /Chrome\//.test(ua) ? "Chrome" : "Browser";
  return `${browser} on ${os}`;
}

function eq(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export class DeskMachine {
  aborted = false;
  abortReason = "";
  keys: GoKeyMaterial | null = null;
  private phonePublic: Uint8Array | null = null;
  private sendSeq = 0;
  private recvSeq = 0;
  private replies = new Map<number, Record<string, unknown>>();

  constructor(
    readonly sidB64: string,
    readonly deskPrivate: Uint8Array,
    readonly deskPublic: Uint8Array,
  ) {}

  get matchCode(): number | null {
    return this.keys?.matchCode ?? null;
  }

  private get sid(): Uint8Array {
    return b64urlDecode(this.sidB64);
  }

  async sendEvent(event: Record<string, unknown>): Promise<Record<string, unknown>> {
    if (this.aborted || !this.keys) throw new Error("no session keys");
    const seq = ++this.sendSeq;
    const box = await sealJson(this.keys.kDp, this.sid, 2, seq, event);
    return { t: "box", d: 2, seq, c: b64url(box) };
  }

  remember(seq: number, wire: Record<string, unknown>) {
    this.replies.set(seq, wire);
  }

  async receive(wire: Record<string, unknown>): Promise<GoRecv> {
    if (this.aborted) return { hello: false, resend: [] };
    if (wire.t === "hello") return this.onHello(wire);
    if (wire.t === "box") return this.onBox(wire);
    return { hello: false, resend: [] };
  }

  private async onHello(wire: Record<string, unknown>): Promise<GoRecv> {
    if (wire.v !== 1 || typeof wire.ppk !== "string") {
      this.aborted = true;
      this.abortReason = "version";
      return { hello: false, resend: [] };
    }
    let ppk: Uint8Array;
    try {
      ppk = b64urlDecode(wire.ppk);
      if (ppk.length !== 65 || ppk[0] !== 0x04) throw new Error("public key");
    } catch {
      this.aborted = true;
      this.abortReason = "public key";
      return { hello: false, resend: [] };
    }
    if (this.phonePublic) {
      if (!eq(this.phonePublic, ppk)) {
        this.aborted = true;
        this.abortReason = "competing";
      }
      return { hello: false, resend: [] };
    }
    const z = await sharedSecret(this.deskPrivate, this.deskPublic, ppk);
    this.phonePublic = ppk;
    this.keys = await deriveGoKeys(z, this.sid, this.deskPublic, ppk);
    return { hello: true, resend: [] };
  }

  private async onBox(wire: Record<string, unknown>): Promise<GoRecv> {
    if (!this.keys) return { hello: false, resend: [] };
    const direction = wire.d;
    const seq = wire.seq;
    const c = wire.c;
    if (direction !== 1 || typeof seq !== "number" || typeof c !== "string") {
      this.aborted = true;
      this.abortReason = "malformed";
      return { hello: false, resend: [] };
    }
    let event: Record<string, unknown>;
    try {
      event = await openJson(this.keys.kPd, this.sid, 1, seq, b64urlDecode(c));
    } catch {
      this.aborted = true;
      this.abortReason = "tamper";
      return { hello: false, resend: [] };
    }
    if (seq <= this.recvSeq) {
      const again = this.replies.get(seq);
      return { hello: false, resend: again ? [again] : [] };
    }
    this.recvSeq = seq;
    return { hello: false, event, seq, resend: [] };
  }
}
