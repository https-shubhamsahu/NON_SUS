// Optional Gemini document insights. Core sharing does not call this.
// Secret: GEMINI_API_KEY (never ship it in the Flutter client).
// Enable the client with --dart-define=INTELLIGENCE_PROVIDER=gemini

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) return json({ error: "Gemini is not configured" }, 503);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";
  if (
    !supabaseUrl || !anonKey || !serviceRoleKey ||
    !authHeader.startsWith("Bearer ")
  ) {
    return json({ error: "Unauthorized" }, 401);
  }
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) return json({ error: "Unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const title = String(body.title ?? "").slice(0, 200);
  const mimeType = String(body.mime_type ?? "").slice(0, 100);
  const text = String(body.text ?? "").slice(0, 12000);
  if (!title && !text) return json({ error: "Nothing to inspect" }, 400);

  // This optional endpoint spends the owner's Gemini quota. The database
  // function is service-role-only and atomically enforces the per-user hourly
  // budget before any provider request leaves this boundary.
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { data: withinBudget, error: budgetError } = await admin.rpc(
    "consume_optional_service_budget",
    {
      p_user_id: userData.user.id,
      p_service: "document-intelligence",
    },
  );
  if (budgetError) {
    console.error("document-intelligence: budget check failed", budgetError);
    return json({ error: "Service is temporarily unavailable" }, 503);
  }
  if (!withinBudget) {
    return json({ error: "Hourly document-insight limit reached" }, 429);
  }

  const prompt =
    `Classify and summarize this document the user already has access to.\n` +
    `Title: ${title}\nType: ${mimeType}\n\n${text}\n\n` +
    `Reply as JSON: {"summary": string, "classification": string, "highlights": string[]}`;

  const geminiRes = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 512 },
      }),
    },
  );
  if (!geminiRes.ok) {
    return json({ error: "Insight provider failed" }, 502);
  }
  const geminiJson = await geminiRes.json();
  const raw = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  try {
    const parsed = JSON.parse(raw.replace(/```json|```/g, "").trim());
    return json({
      summary: String(parsed.summary ?? ""),
      classification: String(parsed.classification ?? "Document"),
      highlights: Array.isArray(parsed.highlights)
        ? parsed.highlights.slice(0, 8)
        : [],
    });
  } catch {
    return json({
      summary: String(raw).slice(0, 600),
      classification: "Document",
      highlights: [],
    });
  }
});
