'use client';

import { useState, useMemo, useDeferredValue } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { gradeLabels, trackLabels } from '@/lib/types';
import { Eye, MessageCircle, Search, CheckCircle, Clock, Loader2 } from 'lucide-react';

export interface UserRow {
  id: string;
  display_name: string;
  role: string;
  grade?: string | null;
  track?: string | null;
  language?: string | null;
  referral_code?: string;
  balance: number;
  created_at: string;
  phone?: string;
  is_pending: boolean;
}

function whatsappUrl(user: UserRow) {
  const rawPhone = user.phone ? user.phone.replace(/\D/g, '') : '';
  const intlPhone = rawPhone.startsWith('01') ? `2${rawPhone}` : rawPhone;
  if (!intlPhone) return null;
  return `https://wa.me/${intlPhone}?text=${encodeURIComponent(
    `مرحباً ${user.display_name || ''}، معك إدارة منصة Solver بخصوص طلب تفعيل حسابك...`
  )}`;
}

function RoleBadge({ role }: { role: string }) {
  if (role === 'merchant') {
    return (
      <span className="inline-flex items-center rounded-full border border-[#D4AF37]/30 bg-[#D4AF37]/15 px-2 py-0.5 text-[11px] font-semibold text-[#D4AF37]">
        تاجر
      </span>
    );
  }
  if (role === 'admin') {
    return (
      <span className="inline-flex items-center rounded-full border border-[#800020]/40 bg-[#800020]/25 px-2 py-0.5 text-[11px] font-semibold text-[#D4AF37]">
        أدمن
      </span>
    );
  }
  return null;
}

function StatusChip({ pending }: { pending: boolean }) {
  return pending ? (
    <span className="inline-flex items-center gap-1 rounded-full border border-[#D4AF37]/30 bg-[#D4AF37]/15 px-2.5 py-1 text-xs font-medium text-[#D4AF37]">
      <Clock size={11} />
      قيد المراجعة
    </span>
  ) : (
    <span className="inline-flex items-center gap-1 rounded-full border border-[#4CAF50]/30 bg-[#4CAF50]/15 px-2.5 py-1 text-xs font-medium text-[#4CAF50]">
      <CheckCircle size={11} />
      مفعّل
    </span>
  );
}

export function UsersTable({ initialUsers }: { initialUsers: UserRow[] }) {
  const router = useRouter();
  const [filter, setFilter] = useState<'all' | 'pending' | 'active'>('all');
  const [search, setSearch] = useState('');
  const [approvingId, setApprovingId] = useState<string | null>(null);
  const deferredSearch = useDeferredValue(search);

  async function approve(userId: string) {
    setApprovingId(userId);
    try {
      const res = await fetch('/api/admin/set-approval', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, approved: true }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.error || 'فشل تفعيل الحساب');
      }
      router.refresh();
    } catch {
      setApprovingId(null);
    }
  }

  const filteredUsers = useMemo(() => {
    return initialUsers.filter((user) => {
      if (filter === 'pending' && !user.is_pending) return false;
      if (filter === 'active' && user.is_pending) return false;

      if (!deferredSearch.trim()) return true;
      const q = deferredSearch.toLowerCase();
      const name = (user.display_name || '').toLowerCase();
      const phone = (user.phone || '').toLowerCase();
      const id = user.id.toLowerCase();
      return name.includes(q) || phone.includes(q) || id.includes(q);
    });
  }, [initialUsers, filter, deferredSearch]);

  const pendingCount = useMemo(
    () => initialUsers.filter((u) => u.is_pending).length,
    [initialUsers]
  );
  const activeCount = useMemo(
    () => initialUsers.filter((u) => !u.is_pending).length,
    [initialUsers]
  );

  const filterButtons = (
    <div className="flex flex-wrap items-center gap-2">
      <button
        onClick={() => setFilter('all')}
        className={`rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${
          filter === 'all'
            ? 'bg-[#800020] text-white shadow-md'
            : 'bg-[#2A2A2A] text-[#9E9E9E] hover:text-[#E0E0E0]'
        }`}
      >
        الكل ({initialUsers.length})
      </button>
      <button
        onClick={() => setFilter('pending')}
        className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${
          filter === 'pending'
            ? 'bg-[#D4AF37] text-black shadow-md'
            : 'bg-[#2A2A2A] text-[#D4AF37] hover:bg-[#353535]'
        }`}
      >
        <Clock size={12} />
        قيد المراجعة ({pendingCount})
      </button>
      <button
        onClick={() => setFilter('active')}
        className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-xs font-semibold transition-all ${
          filter === 'active'
            ? 'bg-[#4CAF50] text-white shadow-md'
            : 'bg-[#2A2A2A] text-[#4CAF50] hover:bg-[#353535]'
        }`}
      >
        <CheckCircle size={12} />
        المفعلون ({activeCount})
      </button>
    </div>
  );

  const searchBox = (
    <div className="relative w-full sm:w-auto sm:min-w-[260px]">
      <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-[#9E9E9E]" size={16} />
      <input
        type="text"
        placeholder="بحث بالاسم أو رقم الهاتف..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full rounded-xl border border-[#2A2A2A] bg-[#1E1E1E] py-2 pl-4 pr-9 text-xs text-[#E0E0E0] placeholder-[#757575] focus:border-[#D4AF37] focus:outline-none"
      />
    </div>
  );

  const actionButtons = (user: UserRow) => (
    <>
      {user.is_pending && (
        <button
          onClick={() => approve(user.id)}
          disabled={approvingId === user.id}
          className="inline-flex touch-manipulation items-center gap-1.5 rounded-lg bg-[#4CAF50]/20 px-3 py-2 text-xs font-semibold text-[#4CAF50] transition-colors hover:bg-[#4CAF50]/40 active:scale-95 disabled:opacity-60"
        >
          {approvingId === user.id ? (
            <Loader2 size={13} className="animate-spin" />
          ) : (
            <CheckCircle size={13} />
          )}
          تفعيل
        </button>
      )}
      <Link
        href={`/users/${user.id}`}
        prefetch={false}
        className="inline-flex touch-manipulation items-center gap-1.5 rounded-lg bg-[#800020]/25 px-3 py-2 text-xs font-semibold text-[#D4AF37] transition-colors hover:bg-[#800020]/50 active:scale-95"
      >
        <Eye size={13} />
        إدارة الحساب
      </Link>
    </>
  );

  return (
    <div className="space-y-4">
      {/* Search and Filters Bar */}
      <div className="flex flex-col items-stretch justify-between gap-3 sm:flex-row sm:items-center">
        {filterButtons}
        {searchBox}
      </div>

      {/* Desktop table */}
      <div className="hidden overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] shadow-lg md:block">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-right text-sm">
            <thead className="border-b border-[#3A3A3A] bg-[#2A2A2A] text-[#E0E0E0]">
              <tr>
                <th className="p-3 sm:p-4">اسم الطالب</th>
                <th className="p-3 sm:p-4">رقم الهاتف / WhatsApp</th>
                <th className="p-3 sm:p-4">الحالة</th>
                <th className="p-3 sm:p-4">المرحلة / المسار</th>
                <th className="p-3 sm:p-4">الرصيد</th>
                <th className="p-3 sm:p-4">التاريخ</th>
                <th className="p-3 sm:p-4 text-center">إجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {filteredUsers.length > 0 ? (
                filteredUsers.map((user) => {
                  const waUrl = whatsappUrl(user);
                  return (
                    <tr key={user.id} className="transition-colors hover:bg-[#252525]">
                      <td className="p-3 sm:p-4">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="font-semibold text-[#E0E0E0]">
                            {user.display_name || 'بدون اسم'}
                          </span>
                          <RoleBadge role={user.role} />
                        </div>
                        <div className="font-mono text-xs text-[#757575]">
                          {user.id.slice(0, 8)}...
                        </div>
                      </td>

                      <td className="p-3 sm:p-4">
                        {user.phone ? (
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="font-mono text-xs text-[#E0E0E0]" dir="ltr">
                              {user.phone}
                            </span>
                            {waUrl && (
                              <a
                                href={waUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                title="مراسلة عبر واتساب"
                                className="inline-flex items-center gap-1 rounded-lg bg-[#25D366]/20 px-2 py-1 text-xs font-semibold text-[#25D366] transition-colors hover:bg-[#25D366]/40"
                              >
                                <MessageCircle size={13} />
                                واتساب
                              </a>
                            )}
                          </div>
                        ) : (
                          <span className="text-xs text-[#757575]">—</span>
                        )}
                      </td>

                      <td className="p-3 sm:p-4">
                        <StatusChip pending={user.is_pending} />
                      </td>

                      <td className="p-3 sm:p-4">
                        <div className="text-xs">
                          {user.grade ? gradeLabels[user.grade] || user.grade : '—'}
                        </div>
                        {user.track && (
                          <div className="text-[11px] text-[#9E9E9E]">
                            {trackLabels[user.track] || user.track}
                          </div>
                        )}
                      </td>

                      <td className="p-3 font-bold text-[#E0E0E0] sm:p-4">
                        {user.balance} 🪙
                      </td>

                      <td className="p-3 text-xs text-[#9E9E9E] sm:p-4">
                        {new Date(user.created_at).toLocaleDateString('ar-EG')}
                      </td>

                      <td className="p-3 sm:p-4">
                        <div className="flex items-center justify-center gap-2">
                          {actionButtons(user)}
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-[#9E9E9E]">
                    لا توجد حسابات تطابق البحث أو الفلتر المختار
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Mobile cards */}
      <div className="space-y-3 md:hidden">
        {filteredUsers.length > 0 ? (
          filteredUsers.map((user) => {
            const waUrl = whatsappUrl(user);
            return (
              <div
                key={user.id}
                className="rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-4 shadow-lg"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="truncate font-semibold text-[#E0E0E0]">
                        {user.display_name || 'بدون اسم'}
                      </span>
                      <RoleBadge role={user.role} />
                    </div>
                    <div className="mt-0.5 font-mono text-[11px] text-[#757575]" dir="ltr">
                      {user.id.slice(0, 8)}...
                    </div>
                  </div>
                  <StatusChip pending={user.is_pending} />
                </div>

                <div className="mt-3 grid grid-cols-2 gap-2 text-xs">
                  <div className="rounded-xl bg-[#252525] p-2.5">
                    <p className="text-[11px] text-[#9E9E9E]">الرصيد</p>
                    <p className="font-bold text-[#E0E0E0]">{user.balance} 🪙</p>
                  </div>
                  <div className="rounded-xl bg-[#252525] p-2.5">
                    <p className="text-[11px] text-[#9E9E9E]">المرحلة / المسار</p>
                    <p className="truncate text-[#E0E0E0]">
                      {user.grade ? gradeLabels[user.grade] || user.grade : '—'}
                      {user.track ? ` • ${trackLabels[user.track] || user.track}` : ''}
                    </p>
                  </div>
                </div>

                <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    {user.phone && (
                      <span className="font-mono text-xs text-[#E0E0E0]" dir="ltr">
                        {user.phone}
                      </span>
                    )}
                    {waUrl && (
                      <a
                        href={waUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 rounded-lg bg-[#25D366]/20 px-2 py-1 text-xs font-semibold text-[#25D366] active:scale-95"
                      >
                        <MessageCircle size={13} />
                        واتساب
                      </a>
                    )}
                  </div>
                  <span className="text-[11px] text-[#9E9E9E]">
                    {new Date(user.created_at).toLocaleDateString('ar-EG')}
                  </span>
                </div>

                <div className="mt-3 flex items-center gap-2">{actionButtons(user)}</div>
              </div>
            );
          })
        ) : (
          <div className="rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-8 text-center text-[#9E9E9E]">
            لا توجد حسابات تطابق البحث أو الفلتر المختار
          </div>
        )}
      </div>
    </div>
  );
}
