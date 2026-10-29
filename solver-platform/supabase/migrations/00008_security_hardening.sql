-- ============================================================================
-- Solver Platform – Security hardening (C1)
-- ============================================================================
-- Problem (CRITICAL):
--   The original policies on `profiles` allowed any authenticated user to:
--     * INSERT their own row with an arbitrary `role`   -> role = 'admin'
--     * UPDATE any column on their own row while onboard_locked = FALSE,
--       including `role`, `approved`, `trial_used`, `referral_code`, ...
--   That turns any student into an admin (is_admin() reads profiles.role),
--   giving access to every profile, wallet, audit log, and admin RPC.
--
-- Fix:
--   * Self-insert is allowed ONLY as a plain, unapproved, trial-unused
--     student profile with no platform account bound.
--   * Self-update is allowed ONLY while onboarding is unlocked and ONLY
--     when the privileged columns keep their safe values.
--   * Admins keep a dedicated INSERT policy (and SECURITY DEFINER RPCs
--     continue to bypass RLS because the table owner is not subject to it).
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- Drop the vulnerable policies
-- ──────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS profiles_insert_admin ON profiles;
DROP POLICY IF EXISTS profiles_update_own   ON profiles;
DROP POLICY IF EXISTS profiles_insert_own_student ON profiles;

-- ──────────────────────────────────────────────────────────────────────────────
-- INSERT: a user may create only their own safe student profile
-- ──────────────────────────────────────────────────────────────────────────────
CREATE POLICY profiles_insert_own_student ON profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        id = auth.uid()
        AND role = 'student'
        AND approved = FALSE
        AND trial_used = FALSE
        AND onboard_locked = FALSE
        AND platform_login IS NULL
        AND platform_login_norm IS NULL
        AND platform_bound_at IS NULL
    );

-- ──────────────────────────────────────────────────────────────────────────────
-- INSERT: real admins may still create profiles (service_role bypasses RLS)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE POLICY profiles_insert_admin ON profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (is_admin());

-- ──────────────────────────────────────────────────────────────────────────────
-- UPDATE: self-service edits only while onboarding is unlocked
--   Privileged columns are pinned to safe values in WITH CHECK, so a student
--   can no longer promote themselves, auto-approve, reset the trial, or bind a
--   platform account by writing the profile directly.
--   NOTE: binding/onboarding/approval happen through SECURITY DEFINER RPCs,
--   which are not subject to these policies.
-- ──────────────────────────────────────────────────────────────────────────────
CREATE POLICY profiles_update_own ON profiles
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid() AND onboard_locked = FALSE)
    WITH CHECK (
        id = auth.uid()
        AND onboard_locked = FALSE
        AND role = 'student'
        AND approved = FALSE
        AND trial_used = FALSE
        AND platform_login IS NULL
        AND platform_login_norm IS NULL
        AND platform_bound_at IS NULL
    );

-- ──────────────────────────────────────────────────────────────────────────────
-- Defense in depth: anonymous clients never write to profiles
-- ──────────────────────────────────────────────────────────────────────────────
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM anon;

-- ============================================================================
-- DONE
-- ============================================================================