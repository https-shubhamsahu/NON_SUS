// <handle>.nosus.foo -> the Drop page on nosus.foo (GitHub Pages).
//
// The page itself reads location.hostname, so the worker only has to serve
// /to for "/" and pass every other path (/_next/..., favicon) through to the
// same origin. Nothing here sees file bytes: the page seals in the browser
// and talks to Supabase directly.
//
// Handle rules match address_handle_valid() in
// supabase/migrations/20260924110000_nosus_drop.sql.

export interface Env {
  /** Where the static site lives. Default https://nosus.foo. */
  ORIGIN?: string;
}

const APEX = "nosus.foo";

// app and www are real hosts. If they are ever proxied through this route by
// mistake, pass them through untouched so App Links verification and the
// apex keep working.
const PASS_THROUGH = new Set(["app", "www"]);

const RESERVED = new Set([
  "app", "www", "api", "go", "to", "admin", "support", "help", "mail",
  "nosus", "no-sus", "root", "static", "assets", "burn", "redeem", "join",
  "status", "blog", "docs", "login", "signup", "settings",
]);

const HANDLE = /^[a-z0-9](?:[a-z0-9-]{2,18}[a-z0-9])$/;

export function handleFromHost(host: string): string | null {
  const h = host.toLowerCase();
  if (!h.endsWith(`.${APEX}`)) return null;
  const label = h.slice(0, -(APEX.length + 1));
  if (!HANDLE.test(label) || label.includes("--") || RESERVED.has(label)) return null;
  return label;
}

const SECURITY_HEADERS: Record<string, string> = {
  "Referrer-Policy": "no-referrer",
  "Content-Security-Policy": "frame-ancestors 'none'",
  "X-Frame-Options": "DENY",
  "X-Content-Type-Options": "nosniff",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  "X-Robots-Tag": "noindex, nofollow",
};

function withHeaders(res: Response): Response {
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) out.headers.set(k, v);
  return out;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const label = url.hostname.toLowerCase().slice(0, -(APEX.length + 1));
    if (PASS_THROUGH.has(label)) return fetch(request);

    const handle = handleFromHost(url.hostname);
    if (!handle) {
      return withHeaders(new Response("Not a NO SUS address.", { status: 404, headers: { "Content-Type": "text/plain" } }));
    }
    if (request.method !== "GET" && request.method !== "HEAD") {
      return withHeaders(new Response("Method not allowed", { status: 405 }));
    }

    const origin = new URL(env.ORIGIN || `https://${APEX}`);
    const target = new URL(url.pathname === "/" || url.pathname === "" ? "/to" : url.pathname, origin);
    // The page reads the handle from the hostname; the query is kept only for
    // asset cache-busting and never carries anything the page needs.
    target.search = url.pathname === "/" ? "" : url.search;

    const upstream = await fetch(target.toString(), {
      method: request.method,
      headers: { Accept: request.headers.get("Accept") ?? "*/*" },
      redirect: "follow",
    });
    return withHeaders(upstream);
  },
};
