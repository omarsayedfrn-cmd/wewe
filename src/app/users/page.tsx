import Link from 'next/link';
import { createAdminClient } from '@/lib/supabase/server';
import { gradeLabels, trackLabels, languageLabels } from '@/lib/types';
import { Eye } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function UsersPage() {
  const supabase = await createAdminClient();

  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('*, wallets(balance)')
    .order('created_at', { ascending: false });

  if (error) {
    return (
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37] mb-6">المستخدمين</h1>
        <div className="bg-[#CF6679]/10 border border-[#CF6679]/30 text-[#CF6679] p-4 rounded-xl">
          فشل تحميل بيانات المستخدمين: {error.message}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">المستخدمين</h1>
          <p className="text-sm text-[#9E9E9E] mt-1">إجمالي الحسابات المسجلة: {profiles?.length || 0}</p>
        </div>
      </div>

      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
        <div className="overflow-x-auto">
          <table className="w-full text-right text-sm">
            <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
              <tr>
                <th className="p-4">الاسم</th>
                <th className="p-4">الدور</th>
                <th className="p-4">المرحلة / المسار</th>
                <th className="p-4">اللغة</th>
                <th className="p-4">كود الإحالة</th>
                <th className="p-4">الرصيد</th>
                <th className="p-4">التاريخ</th>
                <th className="p-4 text-center">إجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {profiles && profiles.length > 0 ? (
                profiles.map((user: any) => {
                  const balance = user.wallets?.[0]?.balance ?? user.wallets?.balance ?? 0;
                  return (
                    <tr key={user.id} className="hover:bg-[#252525] transition-colors">
                      <td className="p-4">
                        <div className="font-semibold text-[#E0E0E0]">{user.display_name || 'بدون اسم'}</div>
                        <div className="text-xs text-[#9E9E9E]">{user.id}</div>
                      </td>
                      <td className="p-4">
                        <span
                          className={`px-2.5 py-1 rounded-full text-xs font-medium ${
                            user.role === 'admin'
                              ? 'bg-[#800020]/30 text-[#E0E0E0] border border-[#800020]'
                              : user.role === 'merchant'
                              ? 'bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/40'
                              : 'bg-[#2A2A2A] text-[#9E9E9E]'
                          }`}
                        >
                          {user.role}
                        </span>
                      </td>
                      <td className="p-4">
                        <div>{user.grade ? gradeLabels[user.grade] || user.grade : '—'}</div>
                        {user.track && (
                          <div className="text-xs text-[#9E9E9E]">
                            {trackLabels[user.track] || user.track}
                          </div>
                        )}
                      </td>
                      <td className="p-4">
                        {user.language ? languageLabels[user.language] || user.language : '—'}
                      </td>
                      <td className="p-4 font-mono text-xs text-[#D4AF37]">
                        {user.referral_code}
                      </td>
                      <td className="p-4 font-bold text-[#E0E0E0]">
                        {balance} 🪙
                      </td>
                      <td className="p-4 text-xs text-[#9E9E9E]">
                        {new Date(user.created_at).toLocaleDateString('ar-EG')}
                      </td>
                      <td className="p-4 text-center">
                        <Link
                          href={`/users/${user.id}`}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#800020]/20 hover:bg-[#800020]/40 text-[#D4AF37] rounded-lg transition-colors text-xs"
                        >
                          <Eye size={14} />
                          عرض
                        </Link>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={8} className="p-8 text-center text-[#9E9E9E]">
                    لا يوجد مستخدمين مسجلين بعد
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
