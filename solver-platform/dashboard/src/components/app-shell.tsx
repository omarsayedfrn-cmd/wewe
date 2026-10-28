'use client';

import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import { Menu } from 'lucide-react';
import { Sidebar } from '@/components/sidebar';

export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [openPath, setOpenPath] = useState<string | null>(null);

  // The drawer is tied to the route it was opened on, so navigating to a new
  // page closes it automatically without an extra render cycle.
  const open = openPath === pathname;
  const closeDrawer = () => setOpenPath(null);

  // Lock background scrolling while the drawer is open.
  useEffect(() => {
    if (!open) return;

    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  if (pathname === '/login') {
    return <>{children}</>;
  }

  return (
    <div className="flex min-h-dvh w-full">
      <Sidebar className="sticky top-0 hidden h-dvh w-64 shrink-0 lg:flex" />

      {/* Mobile drawer */}
      <div
        className={`fixed inset-0 z-50 lg:hidden ${open ? '' : 'pointer-events-none'}`}
        aria-hidden={!open}
        inert={!open}
      >
        <div
          onClick={closeDrawer}
          className={`absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-200 ${
            open ? 'opacity-100' : 'opacity-0'
          }`}
        />
        <div
          style={{ transform: open ? 'translateX(0)' : 'translateX(100%)' }}
          className="absolute inset-y-0 right-0 w-72 max-w-[85vw] shadow-2xl transition-transform duration-200 ease-out"
        >
          <Sidebar className="flex h-full w-full" onNavigate={closeDrawer} />
        </div>
      </div>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Mobile top bar */}
        <header className="sticky top-0 z-40 flex h-14 items-center justify-between gap-3 border-b border-[#2A2A2A] bg-[#1E1E1E]/95 px-4 backdrop-blur lg:hidden">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#800020]">
              <span className="text-sm font-bold text-[#D4AF37]">S</span>
            </div>
            <span className="text-base font-bold text-[#D4AF37]">Solver</span>
            <span className="text-[11px] text-[#9E9E9E]">لوحة الإدارة</span>
          </div>

          <button
            type="button"
            onClick={() => setOpenPath(pathname)}
            aria-label="فتح القائمة"
            aria-expanded={open}
            className="flex h-10 w-10 touch-manipulation items-center justify-center rounded-xl bg-[#2A2A2A] text-[#E0E0E0] transition-colors hover:bg-[#353535] active:scale-95"
          >
            <Menu size={22} />
          </button>
        </header>

        <main className="flex-1 overflow-x-hidden p-4 pb-[calc(1.25rem+env(safe-area-inset-bottom))] md:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}