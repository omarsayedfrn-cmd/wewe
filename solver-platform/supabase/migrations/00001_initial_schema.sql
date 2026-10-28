-- ============================================================================
-- Solver Platform – Initial Schema Migration
-- ============================================================================
-- يحتوي هذا الملف على كل الجداول، السياسات (RLS)، الدوال (RPCs)،
-- والمحفزات (Triggers) اللازمة لتشغيل منصة Solver.
-- This file contains all tables, RLS policies, RPCs, and triggers
-- needed to bootstrap the Solver Platform.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- 0. Extensions
-- ──────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ──────────────────────────────────────────────────────────────────────────────
-- 1. profiles – الملفات الشخصية للمستخدمين
--    Stores user profile data; linked 1:1 with auth.users.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE profiles (
    id               UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role             TEXT        NOT NULL DEFAULT 'student'
                                CHECK (role IN ('student', 'merchant', 'admin')),
    grade            TEXT        CHECK (grade IN ('grade_1', 'grade_2')),          -- أولى ثانوي / تانية ثانوي
    track            TEXT        CHECK (track IN ('medicine', 'business', 'arts', 'engineering')),  -- مسار تانية ثانوي (NULL for grade_1)
    language         TEXT        NOT NULL CHECK (language IN ('ar', 'en')),        -- عام / لغات
    display_name     TEXT,
    avatar           TEXT,
    referral_code    TEXT        UNIQUE NOT NULL,
    referred_by      TEXT        REFERENCES profiles(referral_code),
    trial_used       BOOLEAN     NOT NULL DEFAULT FALSE,
    onboard_locked   BOOLEAN     NOT NULL DEFAULT FALSE,                          -- TRUE بعد اكتمال الإعداد الأولي
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX idx_profiles_role          ON profiles(role);

-- ──────────────────────────────────────────────────────────────────────────────
-- 2. engines – كتالوج المحركات الستة
--    Catalog of the 6 learning engines (Qureo / Sprix variants).
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE engines (
    code        TEXT PRIMARY KEY,                              -- e.g. 'qureo', 'sprix_en'
    name_ar     TEXT NOT NULL,
    name_en     TEXT NOT NULL,
    platform    TEXT NOT NULL,                                 -- 'qureo' or 'sprix'
    course      TEXT NOT NULL,                                 -- e.g. 'javascript_ar'
    language    TEXT NOT NULL CHECK (language IN ('ar', 'en')),
    max_chapter INTEGER NOT NULL
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 3. engine_access – صلاحيات الوصول للمحركات
--    Which engines a student currently has access to.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE engine_access (
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    engine_code TEXT NOT NULL REFERENCES engines(code),
    PRIMARY KEY (user_id, engine_code)
);

CREATE INDEX idx_engine_access_user_id ON engine_access(user_id);

-- ──────────────────────────────────────────────────────────────────────────────
-- 4. entitlements – الاستحقاقات (مين يقدر يحل إيه)
--    Records of what content each user is entitled to solve.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE entitlements (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    engine_code TEXT        NOT NULL REFERENCES engines(code),
    scope       TEXT        NOT NULL CHECK (scope IN ('full', 'chapter')),
    chapters    INTEGER[]   DEFAULT '{}',                      -- الفصول المحددة لو scope='chapter'
    source      TEXT        NOT NULL CHECK (source IN ('trial', 'purchase', 'gift')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at  TIMESTAMPTZ                                    -- NULL = لا ينتهي
);

CREATE INDEX idx_entitlements_user_id     ON entitlements(user_id);
CREATE INDEX idx_entitlements_engine_code ON entitlements(engine_code);

-- ──────────────────────────────────────────────────────────────────────────────
-- 5. products – حزم العملات (للشحن اليدوي)
--    Coin packages available for manual recharge by merchants.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE products (
    id     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    name   TEXT          NOT NULL,
    coins  INTEGER       NOT NULL,
    price  NUMERIC(10,2) NOT NULL,
    active BOOLEAN       NOT NULL DEFAULT TRUE,
    sort   INTEGER       NOT NULL DEFAULT 0
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 6. pricing – تكلفة فتح المحركات (قابلة للتعديل من لوحة التحكم)
--    Engine unlock costs, editable from the admin dashboard.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE pricing (
    engine_code TEXT NOT NULL REFERENCES engines(code),
    kind        TEXT NOT NULL CHECK (kind IN ('full', 'chapter')),
    cost        INTEGER NOT NULL,                              -- التكلفة بالعملات
    PRIMARY KEY (engine_code, kind)
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 7. wallets – المحافظ
--    One wallet per user; balance must never go negative.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE wallets (
    user_id UUID    PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    balance INTEGER NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 8. wallet_transactions – سجل المعاملات (يُكتب بواسطة RPC فقط)
--    Immutable ledger; rows are inserted only via RPCs.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE wallet_transactions (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    delta      INTEGER     NOT NULL,                           -- موجب = إيداع، سالب = خصم
    reason     TEXT        NOT NULL,                           -- 'purchase', 'recharge', 'referral_signup', 'referral_recharge', 'admin_grant'
    ref_id     TEXT,                                           -- مرجع للكيان المرتبط
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wallet_tx_user_id    ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_tx_created_at ON wallet_transactions(created_at);

-- ──────────────────────────────────────────────────────────────────────────────
-- 9. referrals – الإحالات
--    Tracks who referred whom and reward status.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE referrals (
    referrer_id      UUID    NOT NULL REFERENCES profiles(id),
    referred_id      UUID    NOT NULL REFERENCES profiles(id),
    code             TEXT    NOT NULL,
    signup_reward    INTEGER NOT NULL DEFAULT 0,
    recharge_reward  INTEGER NOT NULL DEFAULT 0,
    status           TEXT    NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'signup_rewarded', 'recharge_rewarded')),
    PRIMARY KEY (referrer_id, referred_id)
);

CREATE INDEX idx_referrals_referred_id ON referrals(referred_id);

-- ──────────────────────────────────────────────────────────────────────────────
-- 10. support_threads – محادثات الدعم (Realtime)
--     Each user can open support threads; admins manage them.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE support_threads (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status          TEXT        NOT NULL DEFAULT 'open'
                                CHECK (status IN ('open', 'closed')),
    last_message_at TIMESTAMPTZ,
    unread_admin    INTEGER     NOT NULL DEFAULT 0,
    unread_user     INTEGER     NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_support_threads_user_id ON support_threads(user_id);
CREATE INDEX idx_support_threads_status  ON support_threads(status);

-- ──────────────────────────────────────────────────────────────────────────────
-- 11. support_messages – رسائل الدعم (Realtime)
--     Messages within a support thread.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE support_messages (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id   UUID        NOT NULL REFERENCES support_threads(id) ON DELETE CASCADE,
    sender_role TEXT        NOT NULL CHECK (sender_role IN ('user', 'admin')),
    body        TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_support_messages_thread_id ON support_messages(thread_id);

-- ──────────────────────────────────────────────────────────────────────────────
-- 12. settings – الإعدادات العامة
--     Global key-value configuration store.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE settings (
    key   TEXT  PRIMARY KEY,
    value JSONB NOT NULL
);

-- ──────────────────────────────────────────────────────────────────────────────
-- 13. audit_logs – سجل التدقيق
--     Admin action audit trail.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE audit_logs (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id   UUID        NOT NULL REFERENCES profiles(id),
    action     TEXT        NOT NULL,
    payload    JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_admin_id   ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);


-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- is_admin() – دالة مساعدة للتحقق من صلاحية الأدمن
--   Returns TRUE if the current authenticated user has role='admin'.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
          AND role = 'admin'
    );
$$;


-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- generate_referral_code – توليد كود إحالة فريد من 6 حروف
--   Auto-generates a unique 6-char alphanumeric referral code for new profiles.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    chars  TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';   -- no I/O/0/1 to avoid confusion
    code   TEXT;
    i      INTEGER;
    exists BOOLEAN;
BEGIN
    IF NEW.referral_code IS NOT NULL AND NEW.referral_code <> '' THEN
        RETURN NEW;
    END IF;

    LOOP
        code := '';
        FOR i IN 1..6 LOOP
            code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;

        SELECT EXISTS(SELECT 1 FROM profiles WHERE referral_code = code) INTO exists;
        IF NOT exists THEN
            NEW.referral_code := code;
            EXIT;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_generate_referral_code
    BEFORE INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION generate_referral_code();

-- ──────────────────────────────────────────────────────────────────────────────
-- auto_create_wallet – إنشاء محفظة تلقائياً عند إضافة ملف شخصي جديد
--   Automatically creates a wallet row when a new profile is inserted.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION auto_create_wallet()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO wallets (user_id, balance)
    VALUES (NEW.id, 0)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_auto_create_wallet
    AFTER INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_wallet();


-- ============================================================================
-- RLS – سياسات أمان الصفوف (Row-Level Security)
-- ============================================================================

-- ── profiles ─────────────────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ بياناته فقط – Users can read their own row
CREATE POLICY profiles_select_own ON profiles
    FOR SELECT USING (id = auth.uid() OR is_admin());

-- المستخدم يقدر يعدل بياناته لو لسه ما اكتمل الإعداد – Update only if onboarding not locked
CREATE POLICY profiles_update_own ON profiles
    FOR UPDATE USING (id = auth.uid() AND onboard_locked = FALSE)
    WITH CHECK (id = auth.uid() AND onboard_locked = FALSE);

-- الأدمن يقدر يعدل أي ملف شخصي – Admins can update any profile
CREATE POLICY profiles_update_admin ON profiles
    FOR UPDATE USING (is_admin())
    WITH CHECK (is_admin());

-- الأدمن يقدر يضيف ملفات شخصية – Admins can insert profiles
CREATE POLICY profiles_insert_admin ON profiles
    FOR INSERT WITH CHECK (is_admin() OR id = auth.uid());

-- ── engines ──────────────────────────────────────────────────────────────────
ALTER TABLE engines ENABLE ROW LEVEL SECURITY;

-- الكل يقدر يقرأ – Readable by all authenticated users
CREATE POLICY engines_select_authenticated ON engines
    FOR SELECT USING (auth.role() = 'authenticated');

-- ── engine_access ────────────────────────────────────────────────────────────
ALTER TABLE engine_access ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ صلاحياته فقط – Users see their own access
CREATE POLICY engine_access_select_own ON engine_access
    FOR SELECT USING (user_id = auth.uid() OR is_admin());

-- الأدمن يقدر يضيف/يعدل/يحذف – Admins can manage all
CREATE POLICY engine_access_insert_admin ON engine_access
    FOR INSERT WITH CHECK (is_admin());

CREATE POLICY engine_access_update_admin ON engine_access
    FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

CREATE POLICY engine_access_delete_admin ON engine_access
    FOR DELETE USING (is_admin());

-- ── entitlements ─────────────────────────────────────────────────────────────
ALTER TABLE entitlements ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ استحقاقاته – Users see their own entitlements
CREATE POLICY entitlements_select_own ON entitlements
    FOR SELECT USING (user_id = auth.uid() OR is_admin());

-- لا إدخال مباشر من العميل – No direct insert/update from client (RPC only)
-- الأدمن فقط عبر RPC – Insert policy for SECURITY DEFINER RPCs (they bypass RLS)

-- ── products ─────────────────────────────────────────────────────────────────
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- الكل يقدر يقرأ – Readable by all authenticated
CREATE POLICY products_select_authenticated ON products
    FOR SELECT USING (auth.role() = 'authenticated');

-- ── pricing ──────────────────────────────────────────────────────────────────
ALTER TABLE pricing ENABLE ROW LEVEL SECURITY;

-- الكل يقدر يقرأ – Readable by all authenticated
CREATE POLICY pricing_select_authenticated ON pricing
    FOR SELECT USING (auth.role() = 'authenticated');

-- ── wallets ──────────────────────────────────────────────────────────────────
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ محفظته فقط – Users see their own wallet
CREATE POLICY wallets_select_own ON wallets
    FOR SELECT USING (user_id = auth.uid() OR is_admin());

-- لا تحديث مباشر – No direct update from client (RPC only)

-- ── wallet_transactions ──────────────────────────────────────────────────────
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ معاملاته فقط – Users see their own transactions
CREATE POLICY wallet_tx_select_own ON wallet_transactions
    FOR SELECT USING (user_id = auth.uid() OR is_admin());

-- لا إدخال مباشر – No direct insert from client (RPC only)

-- ── referrals ────────────────────────────────────────────────────────────────
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ إحالاته كمُحيل – Users see referrals where they are the referrer
CREATE POLICY referrals_select_own ON referrals
    FOR SELECT USING (referrer_id = auth.uid() OR is_admin());

-- ── support_threads ──────────────────────────────────────────────────────────
ALTER TABLE support_threads ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ محادثاته – Users see their own threads
CREATE POLICY support_threads_select_own ON support_threads
    FOR SELECT USING (user_id = auth.uid() OR is_admin());

-- المستخدم يقدر ينشئ محادثة – Users can create their own threads
CREATE POLICY support_threads_insert_own ON support_threads
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- الأدمن يقدر يعدل أي محادثة – Admins can update any thread
CREATE POLICY support_threads_update_admin ON support_threads
    FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- ── support_messages ─────────────────────────────────────────────────────────
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- المستخدم يقدر يقرأ رسائل محادثاته – Users see messages in their own threads
CREATE POLICY support_messages_select_own ON support_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM support_threads
            WHERE support_threads.id = support_messages.thread_id
              AND support_threads.user_id = auth.uid()
        )
        OR is_admin()
    );

-- المستخدم يقدر يبعت رسائل في محادثاته (sender_role='user') – Users insert messages to own threads
CREATE POLICY support_messages_insert_own ON support_messages
    FOR INSERT WITH CHECK (
        sender_role = 'user'
        AND EXISTS (
            SELECT 1 FROM support_threads
            WHERE support_threads.id = support_messages.thread_id
              AND support_threads.user_id = auth.uid()
        )
    );

-- الأدمن يقدر يقرأ ويبعت رسائل (sender_role='admin') – Admins can insert with admin role
CREATE POLICY support_messages_insert_admin ON support_messages
    FOR INSERT WITH CHECK (is_admin() AND sender_role = 'admin');

-- ── settings ─────────────────────────────────────────────────────────────────
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- الكل يقدر يقرأ – Readable by all authenticated
CREATE POLICY settings_select_authenticated ON settings
    FOR SELECT USING (auth.role() = 'authenticated');

-- الأدمن بس يقدر يعدل – Only admins can update
CREATE POLICY settings_update_admin ON settings
    FOR UPDATE USING (is_admin()) WITH CHECK (is_admin());

-- ── audit_logs ───────────────────────────────────────────────────────────────
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- الأدمن بس يقدر يقرأ – Only admins can read
CREATE POLICY audit_logs_select_admin ON audit_logs
    FOR SELECT USING (is_admin());

-- لا إدخال مباشر – Insert via RPC only (SECURITY DEFINER bypasses RLS)


-- ============================================================================
-- RPCs – الدوال المخزنة (Stored Procedures)
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- purchase_engine – شراء محرك أو فصل
--   Debit wallet → create entitlement → log transaction. All in one TX.
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
    -- الحصول على هوية المستخدم الحالي
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- التحقق من صحة النطاق
    IF p_scope NOT IN ('full', 'chapter') THEN
        RAISE EXCEPTION 'Invalid scope: %', p_scope;
    END IF;

    -- الحصول على التكلفة من جدول التسعير
    SELECT cost INTO v_cost
    FROM pricing
    WHERE engine_code = p_engine_code AND kind = p_scope;

    IF v_cost IS NULL THEN
        RAISE EXCEPTION 'No pricing found for engine=%, kind=%', p_engine_code, p_scope;
    END IF;

    -- لو النطاق فصل، نحسب التكلفة × عدد الفصول
    IF p_scope = 'chapter' AND array_length(p_chapters, 1) IS NOT NULL THEN
        v_cost := v_cost * array_length(p_chapters, 1);
    END IF;

    -- التحقق من الرصيد
    SELECT balance INTO v_balance
    FROM wallets
    WHERE user_id = v_user_id
    FOR UPDATE;  -- قفل الصف لمنع التعارض

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Wallet not found for user %', v_user_id;
    END IF;

    IF v_balance < v_cost THEN
        RAISE EXCEPTION 'Insufficient balance: have %, need %', v_balance, v_cost;
    END IF;

    -- خصم من المحفظة
    UPDATE wallets
    SET balance = balance - v_cost
    WHERE user_id = v_user_id;

    -- إنشاء الاستحقاق
    INSERT INTO entitlements (user_id, engine_code, scope, chapters, source)
    VALUES (v_user_id, p_engine_code, p_scope, p_chapters, 'purchase')
    RETURNING id INTO v_entitlement_id;

    -- تسجيل المعاملة في السجل
    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (v_user_id, -v_cost, 'purchase', v_entitlement_id::TEXT);

    RETURN v_entitlement_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────────────────────
-- grant_referral_signup – منح مكافأة إحالة التسجيل
--   Credits the referrer when the referred user signs up.
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
    -- البحث عن الإحالة بواسطة المستخدم الجديد
    SELECT referrer_id, code
    INTO v_referrer_id, v_code
    FROM referrals
    WHERE referred_id = p_new_user_id
      AND status = 'pending'
    FOR UPDATE;

    IF v_referrer_id IS NULL THEN
        RETURN;  -- لا توجد إحالة معلقة
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
-- grant_referral_recharge – منح مكافأة إحالة الشحن
--   Credits the referrer when the referred user recharges.
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
    -- البحث عن الإحالة بواسطة المستخدم المُحال
    SELECT referrer_id
    INTO v_referrer_id
    FROM referrals
    WHERE referred_id = p_referred_user_id
      AND status IN ('signup_rewarded', 'pending')
    FOR UPDATE;

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

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_grant_coins – منح عملات من الأدمن
--   Admin-only: credits a user's wallet and logs the action.
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

    -- التحقق من صلاحية الأدمن
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can grant coins';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive';
    END IF;

    -- إيداع في المحفظة
    UPDATE wallets
    SET balance = balance + p_amount
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    -- تسجيل المعاملة
    INSERT INTO wallet_transactions (user_id, delta, reason, ref_id)
    VALUES (p_user_id, p_amount, 'admin_grant', p_note);

    -- تسجيل في سجل التدقيق
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

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_set_entitlement – تعيين استحقاق من الأدمن
--   Admin-only: creates or updates an entitlement for a user.
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
    v_entitlement_id UUID;
BEGIN
    v_admin_id := auth.uid();

    -- التحقق من صلاحية الأدمن
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can set entitlements';
    END IF;

    IF p_scope NOT IN ('full', 'chapter') THEN
        RAISE EXCEPTION 'Invalid scope: %', p_scope;
    END IF;

    -- محاولة تحديث استحقاق موجود أو إنشاء جديد
    -- Check for existing entitlement with same user + engine + scope
    SELECT id INTO v_entitlement_id
    FROM entitlements
    WHERE user_id = p_user_id
      AND engine_code = p_engine_code
      AND scope = p_scope
    LIMIT 1;

    IF v_entitlement_id IS NOT NULL THEN
        -- تحديث الاستحقاق الموجود
        UPDATE entitlements
        SET chapters = p_chapters,
            source = 'gift'
        WHERE id = v_entitlement_id;
    ELSE
        -- إنشاء استحقاق جديد
        INSERT INTO entitlements (user_id, engine_code, scope, chapters, source)
        VALUES (p_user_id, p_engine_code, p_scope, p_chapters, 'gift')
        RETURNING id INTO v_entitlement_id;
    END IF;

    -- تسجيل في سجل التدقيق
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


-- ============================================================================
-- SEED DATA – البيانات الأولية
-- ============================================================================

-- ── كتالوج المحركات ──────────────────────────────────────────────────────────
INSERT INTO engines (code, name_ar, name_en, platform, course, language, max_chapter) VALUES
    ('qureo',       'كيوريو جافاسكريبت',                   'QUREO JavaScript',            'qureo', 'javascript_ar',   'ar', 54),
    ('qureo_js_en', 'كيوريو جافاسكريبت إنجليزي',           'QUREO JavaScript EN',         'qureo', 'javascript_en',   'en', 54),
    ('qureo2',      'كيوريو2 بايثون',                       'QUREO2 Python',               'qureo', 'python_short_ar', 'ar', 25),
    ('qureo2_en',   'كيوريو2 بايثون إنجليزي',               'QUREO2 Python EN',            'qureo', 'python_short_en', 'en', 10),
    ('sprix',       'سبركس الثقافة المالية',                'SPRIX Financial Literacy',    'sprix', 'subject_7',       'ar', 54),
    ('sprix_en',    'سبركس الثقافة المالية إنجليزي',        'SPRIX Financial Literacy EN', 'sprix', 'subject_3',       'en', 137);

-- ── الإعدادات الافتراضية ─────────────────────────────────────────────────────
INSERT INTO settings (key, value) VALUES
    ('referral_signup_reward',          '10'),
    ('referral_recharge_reward',        '20'),
    ('trial_chapters_grade1',           '5'),
    ('trial_chapters_grade2_engineering', '10'),
    ('trial_chapters_grade2_other',     '1');

-- ── التسعير الافتراضي ────────────────────────────────────────────────────────
INSERT INTO pricing (engine_code, kind, cost) VALUES
    ('qureo',       'full',    500),
    ('qureo',       'chapter',  15),
    ('qureo_js_en', 'full',    500),
    ('qureo_js_en', 'chapter',  15),
    ('qureo2',      'full',    300),
    ('qureo2',      'chapter',  15),
    ('qureo2_en',   'full',    200),
    ('qureo2_en',   'chapter',  15),
    ('sprix',       'full',    400),
    ('sprix',       'chapter',  15),
    ('sprix_en',    'full',    400),
    ('sprix_en',    'chapter',  15);


-- ============================================================================
-- REALTIME – تفعيل البث المباشر لجداول الدعم
-- ============================================================================
-- Enable Supabase Realtime for support tables
ALTER PUBLICATION supabase_realtime ADD TABLE support_threads;
ALTER PUBLICATION supabase_realtime ADD TABLE support_messages;


-- ============================================================================
-- GRANTS & PRIVILEGES – منح الصلاحيات لأدوار Supabase
-- ============================================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;


-- ============================================================================
-- DONE ✅
-- تم إنشاء المخطط بنجاح – Schema created successfully
-- ============================================================================
