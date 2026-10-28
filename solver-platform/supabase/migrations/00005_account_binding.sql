-- ============================================================================
-- Solver Platform – Platform account binding
-- ============================================================================
-- Product rules:
--   * A student has ONE platform account (the student login code they use on
--     Qureo / Sprix) bound to their profile. It is shared across every engine
--     they own, so a single code covers all unlocked platforms.
--   * The binding is created the first time the student starts solving and is
--     locked afterwards, even if that first attempt fails.
--   * A student may change the account before the first solve. After that the
--     app asks for an explicit unbind, with a warning about losing the coins.
--   * The account password is never stored server-side; it stays on the
--     student's device (flutter_secure_storage).
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- profiles – أعمدة ربط حساب المنصة
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS platform_login      TEXT,
    ADD COLUMN IF NOT EXISTS platform_login_norm TEXT,
    ADD COLUMN IF NOT EXISTS platform_bound_at   TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_platform_login_norm
    ON profiles(platform_login_norm);

-- ──────────────────────────────────────────────────────────────────────────────
-- bind_platform_account – ربط حساب المنصة (يُستدعى عند أول حل)
--   Idempotent for the same login; raises ACCOUNT_LOCKED when the profile is
--   already bound to a different login.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bind_platform_account(p_login TEXT)
RETURNS profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     UUID := auth.uid();
    v_norm    TEXT;
    v_profile profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_norm := lower(btrim(COALESCE(p_login, '')));
    IF v_norm = '' THEN
        RAISE EXCEPTION 'ACCOUNT_REQUIRED';
    END IF;

    SELECT * INTO v_profile
    FROM profiles
    WHERE id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    -- Already bound: only the same account may proceed.
    IF v_profile.platform_login_norm IS NOT NULL THEN
        IF v_profile.platform_login_norm = v_norm THEN
            RETURN v_profile;
        END IF;
        RAISE EXCEPTION 'ACCOUNT_LOCKED';
    END IF;

    UPDATE profiles
    SET platform_login      = btrim(p_login),
        platform_login_norm = v_norm,
        platform_bound_at   = now()
    WHERE id = v_uid
    RETURNING * INTO v_profile;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION bind_platform_account(TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- unbind_platform_account – فك الربط من التطبيق (بعد تحذير المستخدم)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION unbind_platform_account()
RETURNS profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     UUID := auth.uid();
    v_profile profiles;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE profiles
    SET platform_login      = NULL,
        platform_login_norm = NULL,
        platform_bound_at   = NULL
    WHERE id = v_uid
    RETURNING * INTO v_profile;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION unbind_platform_account() TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_unbind_platform_account – فك الربط من لوحة التحكم (دعم فني)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_unbind_platform_account(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin UUID := auth.uid();
    v_login TEXT;
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can unbind accounts';
    END IF;

    SELECT platform_login INTO v_login FROM profiles WHERE id = p_user_id;
    IF v_login IS NULL THEN
        RETURN;  -- nothing bound, nothing to do
    END IF;

    UPDATE profiles
    SET platform_login      = NULL,
        platform_login_norm = NULL,
        platform_bound_at   = NULL
    WHERE id = p_user_id;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_admin,
        'unbind_platform_account',
        jsonb_build_object('user_id', p_user_id, 'platform_login', v_login)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_unbind_platform_account(UUID) TO authenticated;

-- ============================================================================
-- DONE
-- ============================================================================
