'use client';

import Link, { useLinkStatus } from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Users,
  Package,
  DollarSign,
  Settings,
  MessageCircle,
  BarChart3,
  Shield,
  Rocket,
  Bell,
  Home,
} from 'lucide-react';

const navItems = [
  { href: '/', label: 'الرئيسية', icon: Home },
  { href: '/users', label: 'المستخدمين', icon: Users },
  { href: '/engines', label: 'المحركات', icon: Rocket },
  { href: '/products', label: 'المنتجات', icon: Package },
  { href: '/pricing', label: 'الأسعار', icon: DollarSign },
  { href: '/support', label: 'الدعم', icon: MessageCircle },
  { href: '/notifications', label: 'الإشعارات', icon: Bell },
  { href: '/analytics', label: 'التحليلات', icon: BarChart3 },
  { href: '/settings', label: 'الإعدادات', icon: Settings },
  { href: '/audit', label: 'سجل التدقيق', icon: Shield },
];

function PendingHint() {
  const { pending } = useLinkStatus();

  return (
    <span
      aria-hidden
      className={`ms-auto h-1.5 w-1.5 rounded-full bg-current transition-opacity duration-150 ${
        pending ? 'animate-pulse opacity-100' : 'opacity-0'
      }`}
    />
  );
}

export function Sidebar({
  className = '',
  onNavigate,
}: {
  className?: string;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();

  return (
    <aside
      className={`flex-col border-l border-[#2A2A2A] bg-[#1E1E1E] p-4 ${className}`}
    >
      {/* Logo */}
      <div className="mb-6 flex items-center gap-3 px-3 py-4">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[#800020]">
          <span className="text-xl font-bold text-[#D4AF37]">S</span>
        </div>
        <div>
          <h1 className="text-lg font-bold text-[#D4AF37]">Solver</h1>
          <p className="text-xs text-[#9E9E9E]">لوحة الإدارة</p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-1 overflow-y-auto">
        {navItems.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== '/' && pathname.startsWith(item.href));
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              prefetch={false}
              onClick={onNavigate}
              className={`flex touch-manipulation items-center gap-3 rounded-lg px-3 py-2.5 text-sm transition-colors ${
                isActive
                  ? 'bg-[#800020]/20 font-medium text-[#D4AF37]'
                  : 'text-[#9E9E9E] hover:bg-[#2A2A2A] hover:text-[#E0E0E0] active:bg-[#2A2A2A]'
              }`}
            >
              <Icon size={18} />
              <span>{item.label}</span>
              <PendingHint />
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="mt-auto border-t border-[#2A2A2A] pt-4">
        <p className="text-center text-xs text-[#D4AF37]/50">
          Developed by Omar Sayed
        </p>
      </div>
    </aside>
  );
}