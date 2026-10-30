'use client';

import Link from 'next/link';
import { Bell, MessageCircle, UserPlus, Activity, X } from 'lucide-react';
import { useAlerts, type AlertKind } from '@/components/alerts/alerts-provider';

const icons: Record<AlertKind, typeof Bell> = {
  pending_account: UserPlus,
  support_reply: MessageCircle,
  audit: Activity,
};

const colors: Record<AlertKind, string> = {
  pending_account: '#FFA726',
  support_reply: '#4CAF50',
  audit: '#2196F3',
};

export function AlertsToaster() {
  const { toasts, dismissToast } = useAlerts();

  if (toasts.length === 0) return null;

  return (
    <div className="pointer-events-none fixed inset-x-0 top-[calc(3.5rem+env(safe-area-inset-top))] z-[60] flex flex-col items-center gap-2 px-3 lg:top-4">
      {toasts.map((t) => {
        const Icon = icons[t.kind];
        return (
          <div
            key={t.id}
            className="pointer-events-auto flex w-full max-w-md items-start gap-3 rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-3 shadow-2xl"
            style={{ animation: 'alert-in 220ms ease-out' }}
          >
            <div
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl"
              style={{ backgroundColor: `${colors[t.kind]}22` }}
            >
              <Icon size={18} style={{ color: colors[t.kind] }} />
            </div>
            <Link href={t.href} onClick={() => dismissToast(t.id)} className="min-w-0 flex-1">
              <p className="text-sm font-bold text-[#E0E0E0]">{t.title}</p>
              {t.body && (
                <p className="mt-0.5 line-clamp-2 text-xs text-[#9E9E9E]">{t.body}</p>
              )}
            </Link>
            <button
              type="button"
              onClick={() => dismissToast(t.id)}
              aria-label="إغلاق"
              className="shrink-0 rounded-lg p-1 text-[#9E9E9E] hover:bg-[#2A2A2A] hover:text-[#E0E0E0]"
            >
              <X size={16} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
