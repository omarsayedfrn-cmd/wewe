-- ============================================================================
-- Solver Platform – Manual account approval gate
-- ============================================================================
-- Why:
--   To stop account spam, every new student account stays locked until an
--   admin approves it from the dashboard.
--
-- Rules:
--   * New profiles are created with approved = FALSE (existing rows are kept
--     approved so current users are not locked out).
--   * Admins (and any non-student role) are always treated as approved by the
--     app, so nobody can lock themselves out.
--   * admin_set_approval() flips the flag and writes an audit log entry.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- profiles – عمود الموافقة
--   Existing rows get TRUE, then the column default becomes FALSE so new
--   accounts start pending.
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE profiles
    ALTER COLUMN approved SET DEFAULT FALSE;

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_approved ON profiles(approved);

-- ──────────────────────────────────────────────────────────────────────────────
-- admin_set_approval – تفعيل/تعليق حساب من لوحة التحكم
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_approval(
    p_user_id  UUID,
    p_approved BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin UUID := auth.uid();
BEGIN
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can approve accounts';
    END IF;

    UPDATE profiles
    SET approved    = p_approved,
        approved_at = CASE WHEN p_approved THEN now() ELSE NULL END
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    INSERT INTO audit_logs (admin_id, action, payload)
    VALUES (
        v_admin,
        CASE WHEN p_approved THEN 'approve_account' ELSE 'reject_account' END,
        jsonb_build_object('user_id', p_user_id)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_approval(UUID, BOOLEAN) TO authenticated;

-- ============================================================================
-- DONE
-- ============================================================================
