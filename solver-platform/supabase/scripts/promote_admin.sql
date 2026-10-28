-- ============================================================================
-- Solver Platform – منح صلاحية أدمن لحساب موجود
-- Promote an existing auth user to admin.
-- ============================================================================
-- طريقة الاستخدام / How to use:
--   1) عدّل v_email ليكون إيميل الحساب المطلوب (إيميل تسجيل الدخول).
--      For phone accounts the email is: user_<digits>@solver.app
--      Example: phone 01121433451  ->  user_01121433451@solver.app
--   2) افتح Supabase Dashboard → SQL Editor → New query
--   3) الصق هذا الملف كاملاً واضغط Run
--
-- يشتغل حتى لو الحساب لم يكمل الإعداد الأولي (سيعمل/يحدّث البروفايل).
-- ============================================================================

DO $$
DECLARE
    v_email TEXT := 'user_01121433451@solver.app';  -- <<< عدّل الإيميل هنا
    v_uid   UUID;
BEGIN
    SELECT id INTO v_uid FROM auth.users WHERE email = v_email;

    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'لا يوجد مستخدم بهذا الإيميل: %', v_email;
    END IF;

    INSERT INTO profiles (id, role, language, display_name, onboard_locked)
    VALUES (v_uid, 'admin', 'ar', split_part(v_email, '@', 1), TRUE)
    ON CONFLICT (id) DO UPDATE
        SET role = 'admin',
            onboard_locked = TRUE;

    RAISE NOTICE 'تم ترقية الحساب % (%) إلى أدمن', v_email, v_uid;
END $$;