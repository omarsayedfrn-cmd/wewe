'use client';

import Link from 'next/link';
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
  Home,
} from 'lucide-react';

const navItems = [
  { href: '/', label: 'الرئيسية', icon: Home },
  { href: '/users', label: 'المستخدمين', icon: Users },
  { href: '/engines', label: 'المحركات', icon: Rocket },
  { href: '/products', label: 'المنتجات', icon: Package },
  { href: '/pricing', label: 'الأسعار', icon: DollarSign },
  { href: '/support', label: 'الدعم', icon: MessageCircle },
  { href: '/analytics', label: 'التحليلات', icon: BarChart3 },
  { href: '/settings', label: 'الإعدادات', icon: Settings },
  { href: '/audit', label: 'سجل التدقيق', icon: Shield },
];

export function Sidebar() {
  const pathname = usePathname();

  if (pathname === '/login') {
    return null;
  }

  return (
    <aside className="w-64 bg-[#1E1E1E] border-l border-[#2A2A2A] min-h-screen p-4 flex flex-col">
      {/* Logo */}
      <div className="flex items-center gap-3 px-3 py-4 mb-6">
        <div className="w-10 h-10 bg-[#800020] rounded-xl flex items-center justify-center">
          <span className="text-[#D4AF37] font-bold text-xl">S</span>
        </div>
        <div>
          <h1 className="text-[#D4AF37] font-bold text-lg">Solver</h1>
          <p className="text-[#9E9E9E] text-xs">لوحة الإدارة</p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 space-y-1">
        {navItems.map((item) => {
          const isActive =
            pathname === item.href ||
            (item.href !== '/' && pathname.startsWith(item.href));
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
                isActive
                  ? 'bg-[#800020]/20 text-[#D4AF37] font-medium'
                  : 'text-[#9E9E9E] hover:bg-[#2A2A2A] hover:text-[#E0E0E0]'
              }`}
            >
              <Icon size={18} />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="mt-auto pt-4 border-t border-[#2A2A2A]">
        <p className="text-[#D4AF37]/50 text-xs text-center">
          Developed by Omar Sayed
        </p>
      </div>
    </aside>
  );
}
