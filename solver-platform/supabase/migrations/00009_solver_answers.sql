-- ============================================================================
-- Solver Platform – Server-side answer bank (C2)
-- ============================================================================
-- Problem (CRITICAL):
--   The whole answer bank was shipped inside the APK as `assets/answers.enc`
--   and decrypted with a key that was also compiled into the APK
--   (`libapp.so`). Anyone could extract and decrypt every answer for all six
--   engines, bypassing the paywall entirely.
--
-- Fix:
--   * Answers now live in a private table that is NOT readable by anon or
--     authenticated clients. RLS is enabled with no policies; only the
--     service role (used by the `solver-answers` Edge Function) can read it.
--   * The Edge Function checks the caller's JWT, profile approval, bound
--     platform account, and entitlement before returning any answers.
--   * `engines.chapter_base` maps natural chapter numbers (1..N) to the raw
--     platform chapter ids used as keys in the answer bundle.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- engines – base id for QUREO chapter mapping (90000, 30000, 511000, 531000)
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE engines
    ADD COLUMN IF NOT EXISTS chapter_base INTEGER;

UPDATE engines
SET chapter_base = CASE code
        WHEN 'qureo'       THEN 90000
        WHEN 'qureo_js_en' THEN 30000
        WHEN 'qureo2'      THEN 511000
        WHEN 'qureo2_en'   THEN 531000
        ELSE NULL
    END
WHERE chapter_base IS NULL;

-- ──────────────────────────────────────────────────────────────────────────────
-- solver_answers – private answer bank (one row per engine)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS solver_answers (
    engine_code TEXT        PRIMARY KEY REFERENCES engines(code) ON DELETE CASCADE,
    payload     JSONB       NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE solver_answers ENABLE ROW LEVEL SECURITY;

-- No policies are defined on purpose: anon/authenticated get no rows.
REVOKE ALL ON solver_answers FROM anon, authenticated;
GRANT ALL ON solver_answers TO service_role;

-- ============================================================================
-- DONE
-- ============================================================================