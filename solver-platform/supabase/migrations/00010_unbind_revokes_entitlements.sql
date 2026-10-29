-- ============================================================================
-- Solver Platform – Unbinding revokes engine subscriptions
-- ============================================================================
-- Change of product rule:
--   A subscription covers ONE platform account at a time. Previously
--   unbind_platform_account() only cleared the profile account and kept the
--   entitlement stamps, so after unbinding the engine screen showed both the
--   "open" card (tolerant account match) and the "buy" card (strict match) —
--   a logical contradiction.
--
--   * unbind_platform_account() now also removes the student's entitlements,
--     so an engine must be bought again for another account. trial_used stays
--     TRUE so the one-time trial can never be farmed by unbinding.
--   * admin_unbind_platform_account() revokes them as well (support stays
--     consistent with the student-facing rule).
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- unbind_platform_account – فك الربط من التطبيق (يُلغي اشتراكات المحركات)
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
    v_login   TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_profile
    FROM profiles
    WHERE id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    v_login := v_profile.platform_login;

    -- Cancel every engine subscription for this account.
    DELETE FROM entitlements WHERE user_id = v_uid;

    UPDATE profiles
    SET platform_login      = NULL,
        platform_login_norm = NULL,
        platform_bound_at   = NULL
    WHERE id = v_uid
    RETURNING * INTO v_profile;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_uid,
        'unbind_platform_account',
        jsonb_build_object('user_id', v_uid, 'platform_login', v_login)
    );

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION unbind_platform_account() TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_unbind_platform_account – فك الربط من لوحة التحكم (يُلغي الاشتراكات)
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

    DELETE FROM entitlements WHERE user_id = p_user_id;

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
