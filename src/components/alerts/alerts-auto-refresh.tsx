'use client';

import { useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useAlerts } from '@/components/alerts/alerts-provider';

/**
 * Re-runs the server render whenever a live alert arrives so the /alerts page
 * (and any other server-rendered screen) stays in sync without a manual pull.
 */
export function AlertsAutoRefresh() {
  const router = useRouter();
  const { toasts } = useAlerts();
  const last = useRef<string | null>(null);

  useEffect(() => {
    const id = toasts[0]?.id ?? null;
    if (!id || id === last.current) return;
    last.current = id;
    const t = setTimeout(() => router.refresh(), 700);
    return () => clearTimeout(t);
  }, [toasts, router]);

  return null;
}
