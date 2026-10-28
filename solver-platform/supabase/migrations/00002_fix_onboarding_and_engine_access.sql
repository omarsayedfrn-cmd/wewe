-- ============================================================================
-- Solver Platform – Fix onboarding & engine_access RLS
-- ============================================================================
-- Problems fixed here:
--   1. During onboarding the client inserted the student's initial
--      engine_access rows directly. The only INSERT policy allowed admins, so a
--      normal student received:
--         new row violates row-level security policy for table "engine_access"
--         (code 42501)
--   2. Onboarding was not retry-able: the profile row is written before
--      engine_access, so a failure left a locked profile behind and a retry
--      hit a duplicate-key / locked-update error.
--
-- Solution:
--   * complete_onboarding() – a single SECURITY DEFINER RPC that upserts the
--     profile, derives the allowed engines server-side (never trusting a
--     client-supplied list), inserts engine_access, and handles the referral
--     reward atomically.
--   * engine_access_insert_own – keeps the old direct-insert path working for
--     clients that have not been updated yet, but validates the engine against
--     the student's grade / track / language.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- complete_onboarding – إنهاء الإعداد الأولي بشكل ذري (Atomic onboarding)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION complete_onboarding(
    p_grade        TEXT,
    p_track        TEXT,
    p_language     TEXT,
    p_display_name TEXT DEFAULT NULL,
    p_avatar       TEXT DEFAULT NULL,
    p_referred_by  TEXT DEFAULT NULL
)
RETURNS profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     UUID := auth.uid();
    v_engines TEXT[];
    v_profile profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- ── Validate inputs ──────────────────────────────────────────────────────
    IF p_grade NOT IN ('grade_1', 'grade_2') THEN
        RAISE EXCEPTION 'Invalid grade: %', p_grade;
    END IF;

    IF p_language NOT IN ('ar', 'en') THEN
        RAISE EXCEPTION 'Invalid language: %', p_language;
    END IF;

    IF p_grade = 'grade_1' THEN
        p_track := NULL;
    ELSIF p_track IS NULL
          OR p_track NOT IN ('medicine', 'business', 'arts', 'engineering') THEN
        RAISE EXCEPTION 'Invalid track: %', p_track;
    END IF;

    -- Ignore a referral code that does not exist (avoid FK failure on retry).
    IF p_referred_by IS NOT NULL AND p_referred_by <> ''
       AND NOT EXISTS (
           SELECT 1 FROM profiles WHERE referral_code = p_referred_by
       ) THEN
        p_referred_by := NULL;
    END IF;

    -- ── Derive allowed engines server-side ───────────────────────────────────
    IF p_grade = 'grade_1' THEN
        v_engines := ARRAY[
            CASE WHEN p_language = 'ar' THEN 'qureo' ELSE 'qureo_js_en' END
        ];
    ELSIF p_track = 'engineering' THEN
        v_engines := ARRAY[
            CASE WHEN p_language = 'ar' THEN 'sprix'  ELSE 'sprix_en'    END,
            CASE WHEN p_language = 'ar' THEN 'qureo'  ELSE 'qureo_js_en' END,
            CASE WHEN p_language = 'ar' THEN 'qureo2' ELSE 'qureo2_en'   END
        ];
    ELSE
        v_engines := ARRAY[
            CASE WHEN p_language = 'ar' THEN 'sprix' ELSE 'sprix_en' END
        ];
    END IF;

    -- ── Upsert profile (safe to retry even if a partial profile exists) ──────
    INSERT INTO profiles (
        id, role, grade, track, language, display_name, avatar,
        referred_by, trial_used, onboard_locked
    )
    VALUES (
        v_uid, 'student', p_grade, p_track, p_language, p_display_name, p_avatar,
        NULLIF(p_referred_by, ''), FALSE, TRUE
    )
    ON CONFLICT (id) DO UPDATE
        SET grade          = EXCLUDED.grade,
            track          = EXCLUDED.track,
            language       = EXCLUDED.language,
            display_name   = COALESCE(EXCLUDED.display_name, profiles.display_name),
            avatar         = COALESCE(EXCLUDED.avatar, profiles.avatar),
            referred_by    = COALESCE(profiles.referred_by, EXCLUDED.referred_by),
            onboard_locked = TRUE
    RETURNING * INTO v_profile;

    -- ── Grant engine access (idempotent) ─────────────────────────────────────
    INSERT INTO engine_access (user_id, engine_code)
    SELECT v_uid, unnest(v_engines)
    ON CONFLICT (user_id, engine_code) DO NOTHING;

    -- ── Referral signup reward (non-critical) ────────────────────────────────
    IF p_referred_by IS NOT NULL AND p_referred_by <> '' THEN
        BEGIN
            PERFORM grant_referral_signup(v_uid);
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION complete_onboarding(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
    TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- sync_my_engine_access – إصلاح صلاحيات المحركات الناقصة
--   Re-derives engine_access from the caller's stored profile. Safe to call at
--   any time and fully idempotent. Repairs accounts whose onboarding was
--   interrupted after the profile was written but before engine_access was.
--   Returns the number of rows inserted (0 for admins / profiles w/o grade).
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_my_engine_access()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     UUID := auth.uid();
    v_profile profiles;
    v_engines TEXT[];
    v_count   INTEGER := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_profile FROM profiles WHERE id = v_uid;

    IF NOT FOUND OR v_profile.role <> 'student' OR v_profile.grade IS NULL THEN
        RETURN 0;
    END IF;

    IF v_profile.grade = 'grade_1' THEN
        v_engines := ARRAY[
            CASE WHEN v_profile.language = 'ar' THEN 'qureo' ELSE 'qureo_js_en' END
        ];
    ELSIF v_profile.track = 'engineering' THEN
        v_engines := ARRAY[
            CASE WHEN v_profile.language = 'ar' THEN 'sprix'  ELSE 'sprix_en'    END,
            CASE WHEN v_profile.language = 'ar' THEN 'qureo'  ELSE 'qureo_js_en' END,
            CASE WHEN v_profile.language = 'ar' THEN 'qureo2' ELSE 'qureo2_en'   END
        ];
    ELSE
        v_engines := ARRAY[
            CASE WHEN v_profile.language = 'ar' THEN 'sprix' ELSE 'sprix_en' END
        ];
    END IF;

    INSERT INTO engine_access (user_id, engine_code)
    SELECT v_uid, unnest(v_engines)
    ON CONFLICT (user_id, engine_code) DO NOTHING;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION sync_my_engine_access() TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- Backward-compatible direct insert policy for engine_access
--   Lets older clients insert their own rows, but only for engines that match
--   their declared grade / track / language.
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS engine_access_insert_own ON engine_access;

CREATE POLICY engine_access_insert_own ON engine_access
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM profiles p
            WHERE p.id = auth.uid()
              AND (
                CASE
                    WHEN p.grade = 'grade_1' THEN
                        engine_access.engine_code = CASE
                            WHEN p.language = 'ar' THEN 'qureo'
                            ELSE 'qureo_js_en'
                        END
                    WHEN p.grade = 'grade_2' AND p.track = 'engineering' THEN
                        engine_access.engine_code = ANY (ARRAY[
                            CASE WHEN p.language = 'ar' THEN 'sprix'  ELSE 'sprix_en'    END,
                            CASE WHEN p.language = 'ar' THEN 'qureo'  ELSE 'qureo_js_en' END,
                            CASE WHEN p.language = 'ar' THEN 'qureo2' ELSE 'qureo2_en'   END
                        ])
                    WHEN p.grade = 'grade_2' THEN
                        engine_access.engine_code = CASE
                            WHEN p.language = 'ar' THEN 'sprix'
                            ELSE 'sprix_en'
                        END
                    ELSE FALSE
                END
              )
        )
    );

-- ============================================================================
-- DONE ✅
-- ============================================================================