-- ============================================================================
-- Solver Platform – Full-engine purchases + configurable free trials
-- ============================================================================
-- Product rules:
--   * Paid solving is only for the WHOLE engine (scope = 'full').
--   * Each student gets one trial on the engine configured for their grade /
--     track. The number of trial chapters comes from the dashboard settings:
--       trial_chapters_grade1
--       trial_chapters_grade2_engineering
--       trial_chapters_grade2_other
--   * complete_onboarding() is now idempotent: it never overwrites an already
--     locked profile, so a returning student cannot be re-onboarded by mistake.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- complete_onboarding – early-return for already onboarded profiles
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
    v_existing profiles;
    v_engines TEXT[];
    v_profile profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Already onboarded: never overwrite grade / track / language.
    SELECT * INTO v_existing FROM profiles WHERE id = v_uid;
    IF FOUND AND v_existing.onboard_locked THEN
        RETURN v_existing;
    END IF;

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

    IF p_referred_by IS NOT NULL AND p_referred_by <> ''
       AND NOT EXISTS (
           SELECT 1 FROM profiles WHERE referral_code = p_referred_by
       ) THEN
        p_referred_by := NULL;
    END IF;

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

    INSERT INTO engine_access (user_id, engine_code)
    SELECT v_uid, unnest(v_engines)
    ON CONFLICT (user_id, engine_code) DO NOTHING;

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
-- claim_trial – grant the one-time trial entitlement for this student
--   Picks the trial engine from grade/track/language, reads the chapter count
--   from the dashboard settings, clamps it to the engine's max chapter and
--   creates a scope='chapter', source='trial' entitlement (1..N).
--   Idempotent: returns the existing trial entitlement if one already exists.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION claim_trial()
RETURNS entitlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     UUID := auth.uid();
    v_profile profiles;
    v_engine  TEXT;
    v_key     TEXT;
    v_count   INTEGER;
    v_ent     entitlements;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_profile FROM profiles WHERE id = v_uid;
    IF NOT FOUND OR v_profile.role <> 'student' OR v_profile.grade IS NULL THEN
        RAISE EXCEPTION 'Profile is not ready for a trial';
    END IF;

    -- Return an existing trial entitlement (retry-safe).
    SELECT * INTO v_ent
    FROM entitlements
    WHERE user_id = v_uid AND source = 'trial'
    ORDER BY created_at
    LIMIT 1;
    IF FOUND THEN
        RETURN v_ent;
    END IF;

    IF v_profile.trial_used THEN
        RAISE EXCEPTION 'Trial already used';
    END IF;

    IF v_profile.grade = 'grade_1' THEN
        v_engine := CASE WHEN v_profile.language = 'ar' THEN 'qureo' ELSE 'qureo_js_en' END;
        v_key    := 'trial_chapters_grade1';
    ELSIF v_profile.track = 'engineering' THEN
        v_engine := CASE WHEN v_profile.language = 'ar' THEN 'qureo' ELSE 'qureo_js_en' END;
        v_key    := 'trial_chapters_grade2_engineering';
    ELSE
        v_engine := CASE WHEN v_profile.language = 'ar' THEN 'sprix' ELSE 'sprix_en' END;
        v_key    := 'trial_chapters_grade2_other';
    END IF;

    SELECT COALESCE((value)::INTEGER, 0) INTO v_count
    FROM settings WHERE key = v_key;

    IF v_count IS NULL OR v_count <= 0 THEN
        RAISE EXCEPTION 'Trial is disabled';
    END IF;

    SELECT LEAST(v_count, max_chapter) INTO v_count
    FROM engines WHERE code = v_engine;

    IF v_count IS NULL OR v_count <= 0 THEN
        RAISE EXCEPTION 'Trial is disabled';
    END IF;

    INSERT INTO entitlements (user_id, engine_code, scope, chapters, source)
    VALUES (
        v_uid,
        v_engine,
        'chapter',
        (SELECT array_agg(i) FROM generate_series(1, v_count) AS i),
        'trial'
    )
    RETURNING * INTO v_ent;

    UPDATE profiles SET trial_used = TRUE WHERE id = v_uid;

    RETURN v_ent;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_trial() TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- purchase_engine – full-engine purchases only
--   The app no longer sells individual chapters. Admin gifts/trials use
--   admin_set_entitlement() / claim_trial() instead.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION purchase_engine(
    p_engine_code TEXT,
    p_scope       TEXT,
    p_chapters    INTEGER[] DEFAULT '{}'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id       UUID;
    v_cost          INTEGER;
    v_balance       INTEGER;
    v_entitlement_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_scope <> 'full' THEN
        RAISE EXCEPTION 'Only full-engine purchases are allowed';
    END IF;

    SELECT cost INTO v_cost
    FROM pricing
    WHERE engine_code = p_engine_code AND kind = 'full';

    IF v_cost IS NULL THEN
        RAISE EXCEPTION 'No pricing found for engine=%', p_engine_code;
    END IF;

    SELECT balance INTO v_balance
    FROM wallets
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', v_user_id;
    END IF;
    IF v_balance < v_cost THEN
        RAISE EXCEPTION 'Insufficient balance: have %, need %', v_balance, v_cost;
    END IF;

    UPDATE wallets
    SET balance = balance - v_cost
    WHERE user_id = v_user_id;

    INSERT INTO entitlements (user_id, engine_code, scope, chapters, source)
    VALUES (v_user_id, p_engine_code, 'full', '{}', 'purchase')
    RETURNING id INTO v_entitlement_id;

    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (v_user_id, -v_cost, 'purchase', v_entitlement_id::TEXT);

    RETURN v_entitlement_id;
END;
$$;

GRANT EXECUTE ON FUNCTION purchase_engine(TEXT, TEXT, INTEGER[]) TO authenticated;

-- ============================================================================
-- DONE ✅
-- ============================================================================