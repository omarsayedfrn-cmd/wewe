'use client';

import Link, { useLinkStatus } from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Users, MessageCircle, Bell, LayoutGrid } from 'lucide-react';
import { useAlerts } from '@/components/alerts/alerts-provider';

const tabs = [
  { href: '/', label: 'الرئيسية', icon: Home },
  { href: '/users', label: 'المستخدمين', icon: Users },
  { href: '/support', label: 'الدعم', icon: MessageCircle },
  { href: '/alerts', label: 'التنبيهات', icon: Bell },
] as const;

function Tab({
  href,
  label,
  icon: Icon,
  badge,
}: {
  href: string;
  label: string;
  icon: typeof Home;
  badge?: number;
}) {
  const pathname = usePathname();
  const { pending } = useLinkStatus();
  const isActive =
    pathname === href || (href !== '/' && pathname.startsWith(href));

  return (
    <Link
      href={href}
      className={`relative flex flex-1 touch-manipulation flex-col items-center gap-0.5 py-2 text-[11px] transition-colors ${
        isActive ? 'text-[#D4AF37]' : 'text-[#9E9E9E]'
      }`}
    >
      <span className="relative">
        <Icon size={22} strokeWidth={isActive ? 2.4 : 2} />
        {badge != null && badge > 0 && (
          <span className="absolute -right-2 -top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#800020] px-1 text-[10px] font-bold text-white">
            {badge > 99 ? '99+' : badge}
          </span>
        )}
        <span
          aria-hidden
          className={`absolute -bottom-1 left-1/2 h-1 w-1 -translate-x-1/2 rounded-full bg-current transition-opacity ${
            pending ? 'animate-pulse opacity-100' : 'opacity-0'
          }`}
        />
      </span>
      <span className={isActive ? 'font-semibold' : ''}>{label}</span>
    </Link>
  );
}

export function BottomNav({ onMore }: { onMore: () => void }) {
  const { total } = useAlerts();

  return (
    <nav className="fixed inset-x-0 bottom-0 z-40 border-t border-[#2A2A2A] bg-[#1E1E1E]/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden">
      <div className="flex items-stretch">
        {tabs.map((t) => (
          <Tab
            key={t.href}
            href={t.href}
            label={t.label}
            icon={t.icon}
            badge={t.href === '/alerts' ? total : undefined}
          />
        ))}
        <button
          type="button"
          onClick={onMore}
          className="relative flex flex-1 touch-manipulation flex-col items-center gap-0.5 py-2 text-[11px] text-[#9E9E9E] active:scale-95"
        >
          <LayoutGrid size={22} />
          <span>المزيد</span>
        </button>
      </div>
    </nav>
  );
}
