'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { gradeLabels, trackLabels, languageLabels } from '@/lib/types';
import { Eye, MessageCircle, Search, Filter, Phone, CheckCircle, Clock } from 'lucide-react';

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

export function UsersTable({ initialUsers }: { initialUsers: UserRow[] }) {
  const [filter, setFilter] = useState<'all' | 'pending' | 'active'>('all');
  const [search, setSearch] = useState('');

  const filteredUsers = useMemo(() => {
    return initialUsers.filter((user) => {
      // Filter tab
      if (filter === 'pending' && !user.is_pending) return false;
      if (filter === 'active' && user.is_pending) return false;

      // Search query
      if (!search.trim()) return true;
      const q = search.toLowerCase();
      const name = (user.display_name || '').toLowerCase();
      const phone = (user.phone || '').toLowerCase();
      const id = user.id.toLowerCase();
      return name.includes(q) || phone.includes(q) || id.includes(q);
    });
  }, [initialUsers, filter, search]);

  const pendingCount = initialUsers.filter((u) => u.is_pending).length;
  const activeCount = initialUsers.filter((u) => !u.is_pending).length;

  return (
    <div className="space-y-4">
      {/* Search and Filters Bar */}
      <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              filter === 'all'
                ? 'bg-[#800020] text-white shadow-md'
                : 'bg-[#2A2A2A] text-[#9E9E9E] hover:text-[#E0E0E0]'
            }`}
          >
            الكل ({initialUsers.length})
          </button>
          <button
            onClick={() => setFilter('pending')}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all flex items-center gap-1.5 ${
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
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all flex items-center gap-1.5 ${
              filter === 'active'
                ? 'bg-[#4CAF50] text-white shadow-md'
                : 'bg-[#2A2A2A] text-[#4CAF50] hover:bg-[#353535]'
            }`}
          >
            <CheckCircle size={12} />
            المفعلون ({activeCount})
          </button>
        </div>

        <div className="relative min-w-[260px]">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-[#9E9E9E]" size={16} />
          <input
            type="text"
            placeholder="بحث بالاسم أو رقم الهاتف..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-[#1E1E1E] border border-[#2A2A2A] rounded-xl pr-9 pl-4 py-2 text-xs text-[#E0E0E0] placeholder-[#757575] focus:outline-none focus:border-[#D4AF37]"
          />
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
        <div className="overflow-x-auto">
          <table className="w-full text-right text-sm">
            <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
              <tr>
                <th className="p-4">اسم الطالب</th>
                <th className="p-4">رقم الهاتف / WhatsApp</th>
                <th className="p-4">الحالة</th>
                <th className="p-4">المرحلة / المسار</th>
                <th className="p-4">الرصيد</th>
                <th className="p-4">التاريخ</th>
                <th className="p-4 text-center">إجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {filteredUsers.length > 0 ? (
                filteredUsers.map((user) => {
                  // Normalize phone for WhatsApp URL
                  const rawPhone = user.phone ? user.phone.replace(/\D/g, '') : '';
                  // If Egyptian phone starting with 01, prefix with 2
                  const intlPhone = rawPhone.startsWith('01') ? `2${rawPhone}` : rawPhone;
                  const waUrl = intlPhone
                    ? `https://wa.me/${intlPhone}?text=${encodeURIComponent(
                        `مرحباً ${user.display_name || ''}، معك إدارة منصة Solver بخصوص طلب تفعيل حسابك...`
                      )}`
                    : null;

                  return (
                    <tr key={user.id} className="hover:bg-[#252525] transition-colors">
                      <td className="p-4">
                        <div className="font-semibold text-[#E0E0E0]">
                          {user.display_name || 'بدون اسم'}
                        </div>
                        <div className="text-xs text-[#757575] font-mono">{user.id.slice(0, 8)}...</div>
                      </td>

                      <td className="p-4">
                        {user.phone ? (
                          <div className="flex items-center gap-2">
                            <span className="font-mono text-xs text-[#E0E0E0]" dir="ltr">
                              {user.phone}
                            </span>
                            {waUrl && (
                              <a
                                href={waUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                title="مراسلة عبر واتساب"
                                className="inline-flex items-center gap-1 px-2 py-1 bg-[#25D366]/20 hover:bg-[#25D366]/40 text-[#25D366] rounded-lg text-xs font-semibold transition-colors"
                              >
                                <MessageCircle size={13} />
                                واتساب
                              </a>
                            )}
                          </div>
                        ) : (
                          <span className="text-[#757575] text-xs">—</span>
                        )}
                      </td>

                      <td className="p-4">
                        {user.is_pending ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-[#D4AF37]/15 text-[#D4AF37] border border-[#D4AF37]/30">
                            <Clock size={11} />
                            قيد المراجعة
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-[#4CAF50]/15 text-[#4CAF50] border border-[#4CAF50]/30">
                            <CheckCircle size={11} />
                            مفعّل
                          </span>
                        )}
                      </td>

                      <td className="p-4">
                        <div className="text-xs">
                          {user.grade ? gradeLabels[user.grade] || user.grade : '—'}
                        </div>
                        {user.track && (
                          <div className="text-[11px] text-[#9E9E9E]">
                            {trackLabels[user.track] || user.track}
                          </div>
                        )}
                      </td>

                      <td className="p-4 font-bold text-[#E0E0E0]">
                        {user.balance} 🪙
                      </td>

                      <td className="p-4 text-xs text-[#9E9E9E]">
                        {new Date(user.created_at).toLocaleDateString('ar-EG')}
                      </td>

                      <td className="p-4 text-center">
                        <Link
                          href={`/users/${user.id}`}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#800020]/25 hover:bg-[#800020]/50 text-[#D4AF37] rounded-lg transition-colors text-xs font-semibold"
                        >
                          <Eye size={13} />
                          إدارة الحساب
                        </Link>
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
    </div>
  );
}
