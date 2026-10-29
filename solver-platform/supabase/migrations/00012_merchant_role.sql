-- ============================================================================
-- Solver Platform – Merchant role
-- ============================================================================
-- Merchants are promoted by an admin from the dashboard (no self-selection).
-- A merchant:
--   * keeps the exact same account-binding + entitlement model as a student;
--   * is granted access to EVERY engine in the catalog;
--   * is never eligible for the free trial (claim_trial already rejects any
--     non-student role) nor for referral rewards;
--   * buys with coins at the normal engine prices. Any discount is applied
--     manually by the admin when recharging the wallet, so no pricing tier is
--     stored here.
--
-- Notes:
--   * This migration never touches engine pricing / purchase logic.
--   * `profiles_update_own` pins role='student' for client writes, but this RPC
--     is SECURITY DEFINER so it bypasses RLS safely.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_set_role – ترقية/تنزيل دور الحساب من لوحة التحكم
--   Only admins may call this, and admin accounts can never be changed so the
--   platform cannot lock itself out. Demoting a merchant back to student
--   rebuilds engine_access from grade / track / language, exactly like
--   onboarding / sync_my_engine_access.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_role(
    p_user_id UUID,
    p_role    TEXT
)
RETURNS profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin   UUID := auth.uid();
    v_old     TEXT;
    v_profile profiles;
    v_engines TEXT[];
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can change roles';
    END IF;

    IF p_role NOT IN ('student', 'merchant') THEN
        RAISE EXCEPTION 'Invalid role: %', p_role;
    END IF;

    SELECT role INTO v_old FROM profiles WHERE id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    -- Never change an admin account.
    IF v_old = 'admin' THEN
        RAISE EXCEPTION 'Cannot change the role of an admin account';
    END IF;

    IF p_role = 'merchant' THEN
        -- Merchants unlock the whole engine catalog.
        INSERT INTO engine_access (user_id, engine_code)
        SELECT p_user_id, code FROM engines
        ON CONFLICT (user_id, engine_code) DO NOTHING;

        UPDATE profiles
        SET role        = 'merchant',
            approved    = TRUE,
            approved_at = COALESCE(approved_at, now())
        WHERE id = p_user_id
        RETURNING * INTO v_profile;
    ELSE
        -- Back to student: rebuild engine_access from the academic profile.
        SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;

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
        ELSIF v_profile.grade = 'grade_2' THEN
            v_engines := ARRAY[
                CASE WHEN v_profile.language = 'ar' THEN 'sprix' ELSE 'sprix_en' END
            ];
        ELSE
            v_engines := ARRAY[]::TEXT[];
        END IF;

        DELETE FROM engine_access WHERE user_id = p_user_id;

        IF array_length(v_engines, 1) IS NOT NULL THEN
            INSERT INTO engine_access (user_id, engine_code)
            SELECT p_user_id, unnest(v_engines)
            ON CONFLICT (user_id, engine_code) DO NOTHING;
        END IF;

        UPDATE profiles
        SET role = 'student'
        WHERE id = p_user_id
        RETURNING * INTO v_profile;
    END IF;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_admin,
        'set_role',
        jsonb_build_object(
            'user_id', p_user_id,
            'old_role', v_old,
            'new_role', p_role
        )
    );

    RETURN v_profile;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_role(UUID, TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────────
-- grant_referral_signup – same contract, but merchants never earn rewards
--   A merchant is excluded as a referrer so "no referral for merchants" holds
--   even if their code was already stored on the referred profile.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION grant_referral_signup(p_new_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_reward      INTEGER;
    v_code        TEXT;
BEGIN
    -- البحث عن الإحالة بواسطة المستخدم الجديد (المُحيل لازم يكون طالب)
    SELECT r.referrer_id, r.code
    INTO v_referrer_id, v_code
    FROM referrals r
    JOIN profiles p ON p.id = r.referrer_id
    WHERE r.referred_id = p_new_user_id
      AND r.status = 'pending'
      AND p.role = 'student'
    FOR UPDATE OF r;

    IF v_referrer_id IS NULL THEN
        RETURN;  -- لا توجد إحالة معلقة / المُحيل تاجر
    END IF;

    -- قراءة قيمة المكافأة من الإعدادات
    SELECT (value)::INTEGER INTO v_reward
    FROM settings
    WHERE key = 'referral_signup_reward';

    IF v_reward IS NULL OR v_reward <= 0 THEN
        RETURN;
    END IF;

    -- إيداع في محفظة المُحيل
    UPDATE wallets
    SET balance = balance + v_reward
    WHERE user_id = v_referrer_id;

    -- تحديث حالة الإحالة
    UPDATE referrals
    SET status = 'signup_rewarded',
        signup_reward = v_reward
    WHERE referrer_id = v_referrer_id
      AND referred_id = p_new_user_id;

    -- تسجيل المعاملة
    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (v_referrer_id, v_reward, 'referral_signup', p_new_user_id::TEXT);
END;
$$;

-- ──────────────────────────────────────────────────────────────────────────────
-- grant_referral_recharge – same contract, but merchants never earn rewards
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION grant_referral_recharge(
    p_referred_user_id UUID,
    p_amount           INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_reward      INTEGER;
BEGIN
    -- البحث عن الإحالة بواسطة المستخدم المُحال (المُحيل لازم يكون طالب)
    SELECT r.referrer_id
    INTO v_referrer_id
    FROM referrals r
    JOIN profiles p ON p.id = r.referrer_id
    WHERE r.referred_id = p_referred_user_id
      AND r.status IN ('signup_rewarded', 'pending')
      AND p.role = 'student'
    FOR UPDATE OF r;

    IF v_referrer_id IS NULL THEN
        RETURN;
    END IF;

    -- قراءة قيمة المكافأة من الإعدادات
    SELECT (value)::INTEGER INTO v_reward
    FROM settings
    WHERE key = 'referral_recharge_reward';

    IF v_reward IS NULL OR v_reward <= 0 THEN
        RETURN;
    END IF;

    -- إيداع في محفظة المُحيل
    UPDATE wallets
    SET balance = balance + v_reward
    WHERE user_id = v_referrer_id;

    -- تحديث حالة الإحالة
    UPDATE referrals
    SET status = 'recharge_rewarded',
        recharge_reward = v_reward
    WHERE referrer_id = v_referrer_id
      AND referred_id = p_referred_user_id;

    -- تسجيل المعاملة
    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (v_referrer_id, v_reward, 'referral_recharge', p_referred_user_id::TEXT);
END;
$$;

-- ============================================================================
-- DONE
-- ============================================================================
