-- ============================================================================
-- Solver Platform – Support thread metadata
-- ============================================================================
-- Previously the student app tried to UPDATE support_threads directly after
-- inserting a message. That update is blocked by RLS for students, and the
-- payload for unread_admin was malformed, so last_message_at / unread counts
-- never changed.
--
-- Fix: maintain the thread metadata with an AFTER INSERT trigger on
-- support_messages (runs SECURITY DEFINER, bypassing RLS), and expose a safe
-- RPC so students can mark their own thread as read.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────────
-- on_support_message_insert – تحديث بيانات المحادثة تلقائياً
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION on_support_message_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE support_threads
    SET last_message_at = NEW.created_at,
        unread_admin = CASE
            WHEN NEW.sender_role = 'user' THEN unread_admin + 1
            ELSE unread_admin
        END,
        unread_user = CASE
            WHEN NEW.sender_role = 'admin' THEN unread_user + 1
            ELSE unread_user
        END
    WHERE id = NEW.thread_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_support_message_insert ON support_messages;
CREATE TRIGGER trg_support_message_insert
    AFTER INSERT ON support_messages
    FOR EACH ROW
    EXECUTE FUNCTION on_support_message_insert();

-- ──────────────────────────────────────────────────────────────────────────────
-- mark_support_thread_read – تصفير عدّاد غير المقروء للمستخدم
-- ──────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION mark_support_thread_read(p_thread_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    UPDATE support_threads
    SET unread_user = 0
    WHERE id = p_thread_id
      AND user_id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_support_thread_read(UUID) TO authenticated;

-- ============================================================================
-- DONE ✅
-- ============================================================================