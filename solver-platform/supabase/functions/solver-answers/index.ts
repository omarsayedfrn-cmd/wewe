// ============================================================================
// Solver Platform – `solver-answers` Edge Function
// ============================================================================
// Returns only the answers the caller is entitled to. The answer bank lives in
// the private `solver_answers` table (no client RLS policies) and is never
// shipped inside the APK.
//
// Deploy:
//   supabase functions deploy solver-answers
//
// Required secrets (normally provided automatically by Supabase):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
// ============================================================================

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return json({ error: "unauthorized" }, 401);
    }
    const jwt = authHeader.slice(7).trim();

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "server_misconfigured" }, 500);
    }

    // Service-role client: bypasses RLS for trusted, server-side reads only.
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !userData?.user) {
      return json({ error: "unauthorized" }, 401);
    }
    const userId = userData.user.id;

    let body: { engine_code?: unknown };
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    const engineCode = typeof body.engine_code === "string"
      ? body.engine_code.trim()
      : "";
    if (!engineCode) {
      return json({ error: "engine_code_required" }, 400);
    }

    // ── Profile / approval / bound account ──────────────────────────────────
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("role, approved, platform_login_norm")
      .eq("id", userId)
      .maybeSingle();

    if (profileError || !profile) {
      return json({ error: "profile_not_found" }, 403);
    }
    if (profile.role === "student" && profile.approved !== true) {
      return json({ error: "account_pending_approval" }, 403);
    }

    // ── Engine ──────────────────────────────────────────────────────────────
    const { data: engine, error: engineError } = await admin
      .from("engines")
      .select("code, platform, max_chapter, chapter_base")
      .eq("code", engineCode)
      .maybeSingle();

    if (engineError || !engine) {
      return json({ error: "unknown_engine" }, 404);
    }

    // ── Entitlements (valid + matching the bound account) ───────────────────
    const { data: entitlements, error: entError } = await admin
      .from("entitlements")
      .select("scope, chapters, platform_login_norm, expires_at")
      .eq("user_id", userId)
      .eq("engine_code", engineCode);

    if (entError) {
      return json({ error: "entitlement_lookup_failed" }, 500);
    }

    const now = Date.now();
    const valid = (entitlements ?? []).filter((e) => {
      if (e.expires_at && new Date(e.expires_at).getTime() <= now) return false;
      // NULL stamp = not yet bound; otherwise it must match the bound account.
      // An unbound profile matches only unstamped entitlements.
      if (e.platform_login_norm == null) return true;
      return e.platform_login_norm === profile.platform_login_norm;
    });

    if (valid.length === 0) {
      return json({ error: "no_entitlement" }, 403);
    }

    const isFull = valid.some((e) => e.scope === "full");
    const allowedNatural = new Set<number>();
    if (!isFull) {
      for (const e of valid) {
        if (e.scope !== "chapter") continue;
        for (const c of (e.chapters ?? [])) {
          if (typeof c === "number" && Number.isFinite(c)) {
            allowedNatural.add(c);
          }
        }
      }
      if (allowedNatural.size === 0) {
        return json({ error: "no_entitled_chapters" }, 403);
      }
    }

    // ── Answer bank ─────────────────────────────────────────────────────────
    const { data: row, error: answerError } = await admin
      .from("solver_answers")
      .select("payload")
      .eq("engine_code", engineCode)
      .maybeSingle();

    if (answerError || !row?.payload) {
      return json({ error: "answers_unavailable" }, 503);
    }

    const payload = row.payload as Record<string, unknown>;

    if (engine.platform === "qureo") {
      const base = Number(engine.chapter_base ?? 0);
      const answers: Record<string, unknown> = {};
      for (const [rawId, chapter] of Object.entries(payload)) {
        const natural = Number(rawId) - base;
        if (isFull || allowedNatural.has(natural)) {
          answers[rawId] = chapter;
        }
      }
      if (Object.keys(answers).length === 0) {
        return json({ error: "no_entitled_chapters" }, 403);
      }
      return json({
        engine_code: engineCode,
        scope: isFull ? "full" : "chapters",
        chapters: [...allowedNatural].sort((a, b) => a - b),
        answers,
      });
    }

    // SPRIX: payload = { chapters, tests, chapter_order }
    if (isFull) {
      return json({
        engine_code: engineCode,
        scope: "full",
        chapters: [],
        answers: {
          chapters: payload.chapters ?? {},
          tests: payload.tests ?? {},
        },
      });
    }

    // Chapter-scoped SPRIX (trial): only the first N chapters in curriculum
    // order. `chapter_order` is stored at upload time because JSON object key
    // order is not reliable for numeric ids.
    const order = Array.isArray(payload.chapter_order)
      ? (payload.chapter_order as unknown[]).map(String)
      : Object.keys((payload.chapters ?? {}) as Record<string, unknown>);
    const chapterMap = (payload.chapters ?? {}) as Record<string, unknown>;
    const limit = Math.max(...allowedNatural);
    const limitedChapters: Record<string, unknown> = {};
    for (const id of order.slice(0, limit)) {
      if (id in chapterMap) limitedChapters[id] = chapterMap[id];
    }

    return json({
      engine_code: engineCode,
      scope: "chapters",
      chapters: [...allowedNatural].sort((a, b) => a - b),
      answers: {
        chapters: limitedChapters,
        // Tests are returned so the solver can progress; they are small and
        // the client still stops after the allowed number of chapters.
        tests: payload.tests ?? {},
      },
    });
  } catch (_error) {
    return json({ error: "internal_error" }, 500);
  }
});