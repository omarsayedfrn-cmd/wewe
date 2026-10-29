-- ============================================================================
-- Solver Platform – Fix the referral-code reward pipeline
-- ============================================================================
-- Problem:
--   * No code ever inserted a row into `referrals`. complete_onboarding() only
--     stored profiles.referred_by and called grant_referral_signup(), which
--     looks for a *pending* referrals row. With no row the lookup always
--     returned NULL, so the signup reward was never paid.
--   * grant_referral_recharge() was never called, so the recharge reward
--     configured from the dashboard was dead as well (manual recharges go
--     through admin_grant_coins()).
--
-- Fix:
--   * complete_onboarding() creates the missing referrals row (once, guarded by
--     ON CONFLICT) from the saved referred_by code, then grants the signup
--     reward. Codes are trimmed/upper-cased and self-referrals are ignored.
--   * admin_grant_coins() notifies the referral pipeline after a recharge.
--   * Backfill referrals rows for profiles that were referred before this
--     migration, so their recharge reward can still be paid. No retroactive
--     signup reward is granted here.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- Backfill missing referrals rows (safe + idempotent)
-- ──────────────────────────────────────────────────────────────────────────────
INSERT INTO referrals (referrer_id, referred_id, code, status)
SELECT r.id, p.id, p.referred_by, 'pending'
FROM profiles p
JOIN profiles r ON r.referral_code = p.referred_by
WHERE p.referred_by IS NOT NULL
  AND p.referred_by <> ''
  AND r.id <> p.id
ON CONFLICT (referrer_id, referred_id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────────
-- complete_onboarding – same contract, now records the referral
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

    -- Normalize the code (codes are upper-case) and ignore unknown / self codes.
    p_referred_by := upper(btrim(COALESCE(p_referred_by, '')));
    IF p_referred_by <> ''
       AND NOT EXISTS (
           SELECT 1 FROM profiles
           WHERE referral_code = p_referred_by
             AND id <> v_uid
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

    -- Record the referral (idempotent) using the code actually saved on the
    -- profile, then pay the signup reward (non-critical).
    IF v_profile.referred_by IS NOT NULL AND v_profile.referred_by <> '' THEN
        BEGIN
            INSERT INTO referrals (referrer_id, referred_id, code, status)
            SELECT r.id, v_uid, v_profile.referred_by, 'pending'
            FROM profiles r
            WHERE r.referral_code = v_profile.referred_by
              AND r.id <> v_uid
            ON CONFLICT (referrer_id, referred_id) DO NOTHING;

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
-- admin_grant_coins – also feed the recharge-referral reward (best effort)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_grant_coins(
    p_user_id UUID,
    p_amount  INTEGER,
    p_note    TEXT DEFAULT ''
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();

    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can grant coins';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;

    UPDATE wallets
    SET balance = balance + p_amount
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (p_user_id, p_amount, 'admin_grant', p_note);

    -- Credit the referrer once, when this recharge belongs to a referred user.
    BEGIN
        PERFORM grant_referral_recharge(p_user_id, p_amount);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_admin_id,
        'grant_coins',
        jsonb_build_object(
            'user_id', p_user_id,
            'amount', p_amount,
            'note', p_note
        )
    );
END;
$$;

-- ============================================================================
-- DONE
-- ============================================================================