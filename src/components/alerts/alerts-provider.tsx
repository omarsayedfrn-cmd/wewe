'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import { createClient } from '@/lib/supabase/client';

export type AlertKind = 'pending_account' | 'support_reply' | 'audit';

export type LiveAlert = {
  id: string;
  kind: AlertKind;
  title: string;
  body?: string;
  href: string;
  at: string;
};

type AlertsContextValue = {
  pendingCount: number;
  unreadCount: number;
  total: number;
  toasts: LiveAlert[];
  dismissToast: (id: string) => void;
  refresh: () => void;
};

const AlertsContext = createContext<AlertsContextValue | null>(null);

const kindMeta: Record<
  AlertKind,
  { title: string; href: string }
> = {
  pending_account: { title: 'حساب جديد محتاج تفعيل', href: '/users' },
  support_reply: { title: 'رسالة دعم محتاجة رد', href: '/support' },
  audit: { title: 'تغيير جديد في النظام', href: '/audit' },
};

export function AlertsProvider({ children }: { children: React.ReactNode }) {
  const [pendingCount, setPendingCount] = useState(0);
  const [unreadCount, setUnreadCount] = useState(0);
  const [toasts, setToasts] = useState<LiveAlert[]>([]);
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const refresh = useCallback(async () => {
    try {
      const sb = createClient();
      const [pending, threads] = await Promise.all([
        sb
          .from('profiles')
          .select('id', { count: 'exact', head: true })
          .eq('role', 'student')
          .eq('approved', false),
        sb
          .from('support_threads')
          .select('id', { count: 'exact', head: true })
          .gt('unread_admin', 0),
      ]);
      setPendingCount(pending.count ?? 0);
      setUnreadCount(threads.count ?? 0);
    } catch {
      // Network hiccup — keep the last known counts.
    }
  }, []);

  const scheduleRefresh = useCallback(() => {
    if (refreshTimer.current) clearTimeout(refreshTimer.current);
    refreshTimer.current = setTimeout(() => refresh(), 400);
  }, [refresh]);

  const pushToast = useCallback((alert: LiveAlert) => {
    setToasts((prev) => {
      if (prev.some((t) => t.id === alert.id)) return prev;
      return [alert, ...prev].slice(0, 4);
    });
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== alert.id));
    }, 6500);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    const initial = setTimeout(refresh, 0);

    const sb = createClient();
    const channel = sb
      .channel('admin-alerts')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'profiles' },
        (payload) => {
          scheduleRefresh();
          const row = payload.new as {
            display_name?: string | null;
            role?: string;
            approved?: boolean;
          };
          if (
            payload.eventType === 'INSERT' &&
            row?.role !== 'admin' &&
            row?.approved === false
          ) {
            pushToast({
              id: `p-${(payload.new as { id: string }).id}`,
              kind: 'pending_account',
              title: kindMeta.pending_account.title,
              body: row.display_name || 'طالب جديد بانتظار التفعيل',
              href: kindMeta.pending_account.href,
              at: new Date().toISOString(),
            });
          }
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'support_threads' },
        (payload) => {
          scheduleRefresh();
          if (payload.eventType === 'INSERT') {
            pushToast({
              id: `t-${(payload.new as { id: string }).id}`,
              kind: 'support_reply',
              title: 'تذكرة دعم جديدة',
              body: 'محادثة دعم جديدة بانتظار الرد',
              href: kindMeta.support_reply.href,
              at: new Date().toISOString(),
            });
          }
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'support_messages' },
        (payload) => {
          const row = payload.new as {
            id: string;
            sender_role?: string;
            body?: string;
            thread_id?: string;
          };
          if (row?.sender_role !== 'user') return;
          scheduleRefresh();
          pushToast({
            id: `m-${row.id}`,
            kind: 'support_reply',
            title: kindMeta.support_reply.title,
            body: (row.body || '').slice(0, 90),
            href: row.thread_id ? `/support/${row.thread_id}` : '/support',
            at: new Date().toISOString(),
          });
        }
      )
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'audit_logs' },
        (payload) => {
          const row = payload.new as { id: string; action?: string };
          pushToast({
            id: `a-${row.id}`,
            kind: 'audit',
            title: kindMeta.audit.title,
            body: row.action,
            href: kindMeta.audit.href,
            at: new Date().toISOString(),
          });
        }
      )
      .subscribe();

    const onVisible = () => {
      if (document.visibilityState === 'visible') refresh();
    };
    document.addEventListener('visibilitychange', onVisible);

    return () => {
      clearTimeout(initial);
      if (refreshTimer.current) clearTimeout(refreshTimer.current);
      document.removeEventListener('visibilitychange', onVisible);
      sb.removeChannel(channel);
    };
  }, [refresh, scheduleRefresh, pushToast]);

  const total = pendingCount + unreadCount;

  return (
    <AlertsContext.Provider
      value={{
        pendingCount,
        unreadCount,
        total,
        toasts,
        dismissToast,
        refresh,
      }}
    >
      {children}
    </AlertsContext.Provider>
  );
}

export function useAlerts() {
  const ctx = useContext(AlertsContext);
  if (!ctx) throw new Error('useAlerts must be used within AlertsProvider');
  return ctx;
}
