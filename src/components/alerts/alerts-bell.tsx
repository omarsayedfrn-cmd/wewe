'use client';

import Link from 'next/link';
import { Bell } from 'lucide-react';
import { useAlerts } from '@/components/alerts/alerts-provider';

export function AlertsBell() {
  const { total, pendingCount, unreadCount } = useAlerts();

  return (
    <Link
      href="/alerts"
      aria-label={`التنبيهات${total > 0 ? ` (${total})` : ''}`}
      className="relative flex h-10 w-10 touch-manipulation items-center justify-center rounded-xl bg-[#2A2A2A] text-[#E0E0E0] transition-colors hover:bg-[#353535] active:scale-95"
    >
      <Bell size={20} />
      {total > 0 && (
        <span className="absolute -right-1 -top-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-[#800020] px-1 text-[11px] font-bold text-white ring-2 ring-[#1E1E1E]">
          {total > 99 ? '99+' : total}
        </span>
      )}
      {total > 0 && (
        <span className="sr-only">
          {pendingCount} حساب محتاج تفعيل و {unreadCount} رسالة محتاجة رد
        </span>
      )}
    </Link>
  );
}
