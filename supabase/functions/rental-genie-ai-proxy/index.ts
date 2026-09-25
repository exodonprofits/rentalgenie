// Rental Genie — AI listing description
//
// publish-listing.html sends { prompt } and gets back { text }: a short listing description drafted
// from the property facts on that page.
//
// Callers must be a signed-in user who belongs to a Rental Genie company. The check runs with the
// caller's own JWT, so row-level security on `companies` decides it; no service-role key is used.
// (Earlier versions had no auth at all and were deployed with verify_jwt = false, so anyone with
// the URL could spend the Anthropic key.) Deployed with verify_jwt = true. Requires the
// ANTHROPIC_API_KEY secret.

import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-sonnet-4-6";
const MAX_PROMPT_CHARS = 4000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Not signed in" }, 401);

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });

  // The anon key is itself a valid JWT, so verify_jwt alone doesn't prove a signed-in user.
  const { data: userData } = await supabase.auth.getUser();
  if (!userData?.user) return json({ error: "Not signed in" }, 401);

  // RLS returns only companies the caller owns or is a member of.
  const { data: companies } = await supabase.from("companies").select("id").limit(1);
  if (!companies?.length) return json({ error: "No Rental Genie workspace" }, 403);

  let body: { prompt?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const prompt = String(body.prompt || "").slice(0, MAX_PROMPT_CHARS);
  if (!prompt.trim()) return json({ error: "Missing prompt" }, 400);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "AI not configured" }, 500);

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 300,
      messages: [{ role: "user", content: prompt }],
    }),
  });

  if (!res.ok) {
    console.error("Anthropic error", res.status, (await res.text()).slice(0, 300));
    return json({ error: res.status === 429 ? "busy" : "ai_unavailable" }, res.status === 429 ? 429 : 502);
  }

  const data = await res.json();
  const text = (data.content || []).find((b: { type: string }) => b.type === "text");
  return json({ text: text ? text.text : "" });
});
