-- ============================================================================
-- Solver Platform – Stamp each entitlement with its platform account
-- ============================================================================
-- Why:
--   Entitlements (engine unlocks) were decoupled from the bound platform
--   account. Unbinding only cleared the profile fields, so a student could
--   unbind, bind a different account and keep solving with the same purchase.
--
-- Fix:
--   * entitlements.platform_login_norm carries the account a purchase belongs
--     to. It is NULL until the account is known (first solve) and then stamped
--     with the bound login.
--   * bind_platform_account() stamps every still-unstamped entitlement.
--   * purchase_engine() / claim_trial() / admin_set_entitlement() stamp newly
--     created entitlements with the account bound at that moment (if any).
--   * unbind_platform_account() is unchanged: it only clears the profile
--     account, the stamps stay, so an unlock can never be reused for another
--     account.
--
-- Access rule (enforced in the app): an entitlement opens an engine only when
-- its stamp matches the profile's bound account, or when it is still NULL.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- entitlements – عمود ختم الحساب
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE entitlements
    ADD COLUMN IF NOT EXISTS platform_login_norm TEXT;

CREATE INDEX IF NOT EXISTS idx_entitlements_platform_login_norm
    ON entitlements(platform_login_norm);

-- ──────────────────────────────────────────────────────────────────────────────
-- bind_platform_account – ربط الحساب + ختم كل الاستحقاقات غير المخوتمة
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

    -- Already bound to a different account → reject.
    IF v_profile.platform_login_norm IS NOT NULL
       AND v_profile.platform_login_norm <> v_norm THEN
        RAISE EXCEPTION 'ACCOUNT_LOCKED';
    END IF;

    -- First bind for this profile.
    IF v_profile.platform_login_norm IS NULL THEN
        UPDATE profiles
        SET platform_login      = btrim(p_login),
            platform_login_norm = v_norm,
            platform_bound_at   = now()
        WHERE id = v_uid
        RETURNING * INTO v_profile;
    END IF;

    -- Stamp every entitlement that does not yet belong to an account.
    UPDATE entitlements
    SET platform_login_norm = v_norm
    WHERE user_id = v_uid
      AND platform_login_norm IS NULL;

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION bind_platform_account(TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- purchase_engine – شراء الفتح الكامل (يُختم بحساب الطالب الحالي إن وُجد)
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
    v_user_id        UUID;
    v_cost           INTEGER;
    v_balance        INTEGER;
    v_login_norm     TEXT;
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

    SELECT platform_login_norm INTO v_login_norm
    FROM profiles WHERE id = v_user_id;

    UPDATE wallets
    SET balance = balance - v_cost
    WHERE user_id = v_user_id;

    INSERT INTO entitlements (user_id, engine_code, scope, chapters, source, platform_login_norm)
    VALUES (v_user_id, p_engine_code, 'full', '{}', 'purchase', v_login_norm)
    RETURNING id INTO v_entitlement_id;

    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (v_user_id, -v_cost, 'purchase', v_entitlement_id::TEXT);

    RETURN v_entitlement_id;
END;
$$;

GRANT EXECUTE ON FUNCTION purchase_engine(TEXT, TEXT, INTEGER[]) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- claim_trial – منح التجربة المجانية (تُختم بحساب الطالب الحالي إن وُجد)
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

    INSERT INTO entitlements (user_id, engine_code, scope, chapters, source, platform_login_norm)
    VALUES (
        v_uid,
        v_engine,
        'chapter',
        (SELECT array_agg(i) FROM generate_series(1, v_count) AS i),
        'trial',
        v_profile.platform_login_norm
    )
    RETURNING * INTO v_ent;

    UPDATE profiles SET trial_used = TRUE WHERE id = v_uid;

    RETURN v_ent;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_trial() TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_set_entitlement – منح صلاحية من الأدمن (تُختم بحساب الطالب الحالي)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_entitlement(
    p_user_id     UUID,
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
    v_admin_id       UUID;
    v_login_norm     TEXT;
    v_entitlement_id UUID;
BEGIN
    v_admin_id := auth.uid();

    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can set entitlements';
    END IF;

    IF p_scope NOT IN ('full', 'chapter') THEN
        RAISE EXCEPTION 'Invalid scope: %', p_scope;
    END IF;

    SELECT platform_login_norm INTO v_login_norm
    FROM profiles WHERE id = p_user_id;

    SELECT id INTO v_entitlement_id
    FROM entitlements
    WHERE user_id = p_user_id
      AND engine_code = p_engine_code
      AND scope = p_scope
    LIMIT 1;

    IF v_entitlement_id IS NOT NULL THEN
        UPDATE entitlements
        SET chapters            = p_chapters,
            source              = 'gift',
            platform_login_norm = COALESCE(platform_login_norm, v_login_norm)
        WHERE id = v_entitlement_id;
    ELSE
        INSERT INTO entitlements (user_id, engine_code, scope, chapters, source, platform_login_norm)
        VALUES (p_user_id, p_engine_code, p_scope, p_chapters, 'gift', v_login_norm)
        RETURNING id INTO v_entitlement_id;
    END IF;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_admin_id,
        'set_entitlement',
        jsonb_build_object(
            'user_id', p_user_id,
            'engine_code', p_engine_code,
            'scope', p_scope,
            'chapters', to_jsonb(p_chapters),
            'entitlement_id', v_entitlement_id
        )
    );

    RETURN v_entitlement_id;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_entitlement(UUID, TEXT, TEXT, INTEGER[]) TO authenticated;

-- ============================================================================
-- DONE
-- ============================================================================
