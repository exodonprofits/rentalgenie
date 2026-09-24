// Rental Genie — Snap it
//
// Reads a receipt (photo or PDF) the landlord already uploaded to Storage and returns a DRAFT
// expense for the page to prefill. Nothing is written to the database here: the landlord reviews
// the draft in the normal form and saves it, the same confirm-first rule as the payment inbox.
//
// POST { kind: "receipt", bucket: "receipts", path: "expenses/<company_id>/<file>", company_id }
// Authorization: Bearer <user JWT>
//
// The file is downloaded and the property list read with the CALLER's JWT, so Storage and table
// RLS decide what they can reach; no service-role key is used. Requires the ANTHROPIC_API_KEY
// secret. Deployed with verify_jwt = true.

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-opus-5";
const MAX_BYTES = 20 * 1024 * 1024;
const IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp", "image/gif"];
const ALLOWED_BUCKETS = ["receipts"];

// Must match the <option> values in add-expense.html.
const EXPENSE_CATEGORIES = [
  "Repairs & Maintenance",
  "Property Management",
  "Utilities",
  "HOA",
  "Insurance",
  "Property Tax",
  "Mortgage Payment",
  "Mortgage Principal",
  "Mortgage Interest",
  "Supplies",
  "Legal & Professional",
  "Advertising",
  "Other",
];

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

const nullable = (schema: Record<string, unknown>) => ({ anyOf: [schema, { type: "null" }] });

function receiptSchema(propertyNames: string[]) {
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      is_receipt: { type: "boolean" },
      not_receipt_reason: nullable({ type: "string" }),
      vendor: nullable({ type: "string" }),
      date: nullable({ type: "string", format: "date" }),
      total: nullable({ type: "number" }),
      category: { type: "string", enum: EXPENSE_CATEGORIES },
      property_name: propertyNames.length
        ? nullable({ type: "string", enum: propertyNames })
        : { type: "null" },
      note: nullable({ type: "string" }),
      details: nullable({ type: "string" }),
      unsure: {
        type: "array",
        items: { type: "string", enum: ["vendor", "date", "total", "category", "property"] },
      },
    },
    required: [
      "is_receipt", "not_receipt_reason", "vendor", "date", "total", "category",
      "property_name", "note", "details", "unsure",
    ],
  };
}

function receiptPrompt(properties: { name: string; address: string | null }[], today: string) {
  const list = properties.length
    ? properties.map((p) => `- ${p.name}${p.address ? ` (${p.address})` : ""}`).join("\n")
    : "(none on file)";
  return `This is a receipt, invoice or bill a landlord uploaded for a rental property. Read it and fill in the expense fields.

Today is ${today}; use it to settle the year when the document omits one.

The landlord's properties:
${list}

- total: the amount actually paid, including tax and tip. For a bill with a balance due, use the amount due.
- category: the closest match for a rental-property expense. Hardware-store materials are Supplies unless the document shows a repair job; a contractor's labor is Repairs & Maintenance.
- property_name: only when the document names a service address or property that matches one above; otherwise null. Don't guess from the vendor's own address.
- note: a short label the landlord would recognise later, like "Water heater repair, inv #1042" (under 80 characters).
- details: the main line items, briefly, or null.
- unsure: every field you could not read clearly or had to infer.
- If this is not a receipt, invoice or bill, set is_receipt false, explain in not_receipt_reason, and leave the other fields null (category "Other").`;
}

function base64(bytes: Uint8Array) {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function mediaTypeFor(blobType: string, path: string) {
  const t = (blobType || "").toLowerCase().split(";")[0];
  if (t === "application/pdf" || IMAGE_TYPES.includes(t)) return t;
  const ext = path.split(".").pop()?.toLowerCase();
  if (ext === "pdf") return "application/pdf";
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  if (ext === "png") return "image/png";
  if (ext === "webp") return "image/webp";
  if (ext === "gif") return "image/gif";
  return null;
}

async function extractReceipt(
  bytes: Uint8Array,
  mediaType: string,
  properties: { name: string; address: string | null }[],
) {
  const anthropic = new Anthropic();
  const fileBlock = mediaType === "application/pdf"
    ? { type: "document", source: { type: "base64", media_type: mediaType, data: base64(bytes) } }
    : { type: "image", source: { type: "base64", media_type: mediaType, data: base64(bytes) } };

  const today = new Date().toISOString().slice(0, 10);
  const names = properties.map((p) => p.name);

  // Cast: output_config.effort/format and fallbacks "default" may be newer than the SDK's types.
  const response = await anthropic.beta.messages.create({
    model: MODEL,
    max_tokens: 8000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: receiptSchema(names) },
    },
    messages: [{
      role: "user",
      content: [fileBlock, { type: "text", text: receiptPrompt(properties, today) }],
    }],
  } as any);

  if (response.stop_reason === "refusal") {
    return { error: "refused", status: 422 };
  }
  if (response.stop_reason === "max_tokens") {
    return { error: "truncated", status: 502 };
  }
  const text = response.content.find((b: any) => b.type === "text") as any;
  if (!text?.text) return { error: "empty", status: 502 };

  let draft: any;
  try {
    draft = JSON.parse(text.text);
  } catch {
    return { error: "bad_json", status: 502 };
  }
  // Belt and braces: never hand back a property the caller can't see.
  if (draft.property_name && !names.includes(draft.property_name)) draft.property_name = null;
  return { draft, model: response.model, usage: response.usage };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "Missing Authorization" }, 401);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const kind = String(body.kind || "");
  if (kind !== "receipt") return json({ error: "Unsupported kind" }, 400);

  const bucket = String(body.bucket || "");
  const path = String(body.path || "");
  const companyId = String(body.company_id || "");
  if (!ALLOWED_BUCKETS.includes(bucket) || !path) return json({ error: "Missing file" }, 400);

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });

  const { data: userData } = await supabase.auth.getUser();
  if (!userData?.user) return json({ error: "Not signed in" }, 401);

  const { data: blob, error: dlErr } = await supabase.storage.from(bucket).download(path);
  if (dlErr || !blob) return json({ error: "File not found or not yours" }, 404);
  if (blob.size > MAX_BYTES) return json({ error: "File too large (20 MB max)" }, 413);

  const mediaType = mediaTypeFor(blob.type, path);
  if (!mediaType) return json({ error: "Unsupported file type — use a photo (JPG/PNG) or PDF" }, 415);

  let properties: { name: string; address: string | null }[] = [];
  if (companyId) {
    const { data } = await supabase.from("properties")
      .select("name,address")
      .eq("company_id", companyId)
      .order("name");
    properties = (data || []).filter((p: any) => p.name);
  }

  try {
    const result = await extractReceipt(new Uint8Array(await blob.arrayBuffer()), mediaType, properties);
    if ("error" in result) return json({ error: result.error }, result.status);
    return json({ ok: true, kind, draft: result.draft, model: result.model });
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) return json({ error: "busy" }, 429);
    if (err instanceof Anthropic.APIError) {
      console.error("Anthropic error", err.status, err.message);
      return json({ error: "ai_unavailable" }, 502);
    }
    console.error(err);
    return json({ error: "unexpected" }, 500);
  }
});
