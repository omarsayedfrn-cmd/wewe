import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createAdminClient } from '@/lib/supabase/server';
import { gradeLabels, trackLabels, languageLabels, reasonLabels } from '@/lib/types';
import { UserActions } from '@/components/user-actions';
import { ArrowRight, User, Wallet, Shield, History, Key, MessageCircle, Phone } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createAdminClient();

  const [profileRes, walletRes, txRes, entitlementsRes, accessRes, enginesRes, authUserRes] =
    await Promise.all([
      supabase.from('profiles').select('*').eq('id', id).single(),
      supabase.from('wallets').select('*').eq('user_id', id).single(),
      supabase
        .from('wallet_transactions')
        .select('*')
        .eq('user_id', id)
        .order('created_at', { ascending: false })
        .limit(20),
      supabase
        .from('entitlements')
        .select('*')
        .eq('user_id', id)
        .order('created_at', { ascending: false }),
      supabase
        .from('engine_access')
        .select('*, engines(*)')
        .eq('user_id', id),
      supabase.from('engines').select('*').order('code'),
      supabase.auth.admin.getUserById(id).catch(() => ({ data: { user: null } })),
    ]);

  if (profileRes.error || !profileRes.data) {
    notFound();
  }

  const profile = profileRes.data;
  const wallet = walletRes.data;
  const transactions = txRes.data || [];
  const entitlements = entitlementsRes.data || [];
  const access = accessRes.data || [];
  const engines = enginesRes.data || [];
  const authUser = authUserRes.data?.user;

  // Extract phone number
  let phone = (authUser?.user_metadata?.phone as string) || '';
  if (!phone && profile.display_name) {
    const match = profile.display_name.match(/\((01[0-9]{9})\)/) || profile.display_name.match(/(01[0-9]{9})/);
    if (match) phone = match[1];
  }
  if (!phone && authUser?.email?.startsWith('user_')) {
    phone = authUser.email.replace('user_', '').replace('@solver.app', '');
  }

  const rawPhone = phone.replace(/\D/g, '');
  const intlPhone = rawPhone.startsWith('01') ? `2${rawPhone}` : rawPhone;
  const waUrl = intlPhone
    ? `https://wa.me/${intlPhone}?text=${encodeURIComponent(
        `مرحباً ${profile.display_name || ''}، معك إدارة منصة Solver بخصوص تفعيل حسابك وشحن رصيدك...`
      )}`
    : null;

  return (
    <div className="space-y-6">
      {/* Top Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link
            href="/users"
            className="p-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl transition-colors"
          >
            <ArrowRight size={18} />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-[#D4AF37]">
              {profile.display_name || 'مستخدم بدون اسم'}
            </h1>
            <p className="text-xs text-[#9E9E9E] font-mono mt-0.5">{profile.id}</p>
          </div>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          {waUrl && (
            <a
              href={waUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex touch-manipulation items-center justify-center gap-2 px-4 py-2 bg-[#25D366] hover:bg-[#20ba59] text-white rounded-xl text-xs font-bold transition-all shadow-md active:scale-95"
            >
              <MessageCircle size={15} />
              مراسلة عبر WhatsApp
            </a>
          )}
          <UserActions
            userId={profile.id}
            engines={engines}
            platformLogin={profile.platform_login}
            approved={profile.approved}
            role={profile.role}
          />
        </div>
      </div>

      {/* Grid Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
          <div className="flex items-center gap-2 text-[#D4AF37] font-semibold mb-4">
            <User size={18} />
            <span>البيانات الشخصية والأكاديمية</span>
          </div>

          <div className="space-y-3 text-sm">
            {phone && (
              <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
                <span className="text-[#9E9E9E]">رقم الهاتف / واتساب:</span>
                <span className="font-mono font-bold text-[#25D366]" dir="ltr">{phone}</span>
              </div>
            )}
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">الدور:</span>
              <span className="font-semibold text-[#E0E0E0]">{profile.role}</span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">المرحلة:</span>
              <span className="font-semibold text-[#E0E0E0]">
                {profile.grade ? gradeLabels[profile.grade] || profile.grade : '—'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">المسار:</span>
              <span className="font-semibold text-[#E0E0E0]">
                {profile.track ? trackLabels[profile.track] || profile.track : '—'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">اللغة:</span>
              <span className="font-semibold text-[#E0E0E0]">
                {profile.language ? languageLabels[profile.language] || profile.language : '—'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">كود الإحالة:</span>
              <span className="font-mono text-[#D4AF37] font-bold">{profile.referral_code}</span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">حساب المنصة المربوط:</span>
              <span className="font-mono font-bold text-[#D4AF37]" dir="ltr">
                {profile.platform_login || '—'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">قفل الاختيار (Onboard):</span>
              <span className={profile.onboard_locked ? 'text-[#4CAF50]' : 'text-[#CF6679]'}>
                {profile.onboard_locked ? 'مقفول ✅' : 'مفتوح ⚠️'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-[#2A2A2A]">
              <span className="text-[#9E9E9E]">حالة الحساب:</span>
              <span className={profile.approved ? 'text-[#4CAF50]' : 'text-[#D4AF37]'}>
                {profile.approved ? 'مفعّل' : 'قيد المراجعة'}
              </span>
            </div>
            <div className="flex justify-between py-1.5">
              <span className="text-[#9E9E9E]">التجربة المجانية:</span>
              <span>{profile.trial_used ? 'مستهلكة' : 'متاحة'}</span>
            </div>
          </div>
        </div>

        {/* Wallet Card */}
        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
          <div className="flex items-center gap-2 text-[#D4AF37] font-semibold mb-4">
            <Wallet size={18} />
            <span>المحفظة والرصيد</span>
          </div>

          <div className="p-4 bg-gradient-to-br from-[#800020]/30 to-[#121212] border border-[#800020]/40 rounded-xl text-center mb-4">
            <p className="text-xs text-[#9E9E9E]">الرصيد المتوفر</p>
            <p className="text-4xl font-extrabold text-[#D4AF37] mt-1">
              {wallet?.balance ?? 0}
            </p>
            <p className="text-xs text-[#E0E0E0] mt-1">عملة ذهبية</p>
          </div>

          <p className="text-xs text-[#9E9E9E] leading-relaxed">
            الرصيد يتم تعديله حصراً عبر عمليات الشراء التلقائية أو منح الإدارة اليدوي لضمان سلامة الـ Ledger.
          </p>
        </div>

        {/* Engine Access */}
        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
          <div className="flex items-center gap-2 text-[#D4AF37] font-semibold mb-4">
            <Shield size={18} />
            <span>المحركات المتاحة للطالب</span>
          </div>

          {access.length > 0 ? (
            <div className="space-y-2">
              {access.map((acc: any) => (
                <div
                  key={acc.engine_code}
                  className="p-3 bg-[#2A2A2A] rounded-xl flex items-center justify-between text-sm"
                >
                  <span className="font-semibold text-[#E0E0E0]">
                    {acc.engines?.name_ar || acc.engine_code}
                  </span>
                  <span className="text-xs font-mono text-[#D4AF37] bg-[#1E1E1E] px-2 py-0.5 rounded">
                    {acc.engine_code}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-[#9E9E9E]">لا توجد محركات مسندة لهذا الطالب بعد</p>
          )}
        </div>
      </div>

      {/* Entitlements Table */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
        <div className="flex items-center gap-2 text-[#D4AF37] font-semibold mb-4">
          <Key size={18} />
          <span>الصلاحيات المفتوحة (Entitlements)</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-right text-sm">
            <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
              <tr>
                <th className="p-3">المحرك</th>
                <th className="p-3">النطاق</th>
                <th className="p-3">الفصول المفتوحة</th>
                <th className="p-3">المصدر</th>
                <th className="p-3">تاريخ الفتح</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {entitlements.length > 0 ? (
                entitlements.map((ent: any) => (
                  <tr key={ent.id} className="hover:bg-[#252525]">
                    <td className="p-3 font-semibold text-[#E0E0E0]">{ent.engine_code}</td>
                    <td className="p-3">
                      <span className="px-2 py-0.5 bg-[#800020]/20 text-[#D4AF37] rounded text-xs">
                        {ent.scope === 'full' ? 'كامل المحرك' : 'فصول محددة'}
                      </span>
                    </td>
                    <td className="p-3 text-xs">
                      {ent.scope === 'full'
                        ? 'جميع الفصول'
                        : ent.chapters?.length > 0
                        ? ent.chapters.join(', ')
                        : '—'}
                    </td>
                    <td className="p-3 text-xs text-[#9E9E9E]">{ent.source}</td>
                    <td className="p-3 text-xs text-[#9E9E9E]">
                      {new Date(ent.created_at).toLocaleString('ar-EG')}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={5} className="p-4 text-center text-[#9E9E9E]">
                    لا توجد فصول أو محركات مفتوحة لهذا المستخدم
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Transactions Table */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
        <div className="flex items-center gap-2 text-[#D4AF37] font-semibold mb-4">
          <History size={18} />
          <span>سجل حركات المحفظة (Wallet Ledger)</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-right text-sm">
            <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
              <tr>
                <th className="p-3">القيمة</th>
                <th className="p-3">السبب</th>
                <th className="p-3">مرجع / ملاحظة</th>
                <th className="p-3">التاريخ</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {transactions.length > 0 ? (
                transactions.map((tx: any) => (
                  <tr key={tx.id} className="hover:bg-[#252525]">
                    <td className="p-3">
                      <span
                        className={`font-bold ${
                          tx.delta > 0 ? 'text-[#4CAF50]' : 'text-[#CF6679]'
                        }`}
                      >
                        {tx.delta > 0 ? `+${tx.delta}` : tx.delta} 🪙
                      </span>
                    </td>
                    <td className="p-3 text-sm">{reasonLabels[tx.reason] || tx.reason}</td>
                    <td className="p-3 text-xs text-[#9E9E9E] font-mono">{tx.ref_id || '—'}</td>
                    <td className="p-3 text-xs text-[#9E9E9E]">
                      {new Date(tx.created_at).toLocaleString('ar-EG')}
                    </td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td colSpan={4} className="p-4 text-center text-[#9E9E9E]">
                    لا توجد عمليات سابقة في المحفظة
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
