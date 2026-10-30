import Link from 'next/link';
import { createAdminClient } from '@/lib/supabase/server';
import { AlertsAutoRefresh } from '@/components/alerts/alerts-auto-refresh';
import { BellRing, UserPlus, MessageCircle, Activity, ArrowLeft } from 'lucide-react';

export const dynamic = 'force-dynamic';

const actionLabels: Record<string, string> = {
  send_notification: 'إرسال إشعار',
  set_approval: 'تعديل تفعيل حساب',
  set_role: 'تعديل صلاحية',
  set_entitlement: 'تعديل صلاحيات محرك',
  grant_coins: 'منح عملات',
  unbind_account: 'فك ربط حساب',
  update_pricing: 'تحديث الأسعار',
  update_products: 'تحديث المنتجات',
  update_settings: 'تحديث الإعدادات',
  support_reply: 'رد على الدعم',
};

function timeAgo(iso: string) {
  return new Date(iso).toLocaleString('ar-EG', {
    dateStyle: 'short',
    timeStyle: 'short',
  });
}

export default async function AlertsPage() {
  const supabase = await createAdminClient();

  const [pendingRes, threadsRes, auditRes] = await Promise.all([
    supabase
      .from('profiles')
      .select('id, display_name, grade, created_at')
      .eq('role', 'student')
      .eq('approved', false)
      .order('created_at', { ascending: false })
      .limit(50),
    supabase
      .from('support_threads')
      .select('id, user_id, unread_admin, last_message_at, profiles(*)')
      .gt('unread_admin', 0)
      .order('last_message_at', { ascending: false, nullsFirst: false })
      .limit(50),
    supabase
      .from('audit_logs')
      .select('id, action, created_at, profiles(display_name)')
      .order('created_at', { ascending: false })
      .limit(30),
  ]);

  const pending = pendingRes.data ?? [];
  const threads = threadsRes.data ?? [];
  const audit = auditRes.data ?? [];

  return (
    <div className="space-y-6">
      <AlertsAutoRefresh />

      <div>
        <h1 className="flex items-center gap-2 text-2xl font-bold text-[#D4AF37]">
          <BellRing size={24} />
          التنبيهات
        </h1>
        <p className="mt-1 text-sm text-[#9E9E9E]">
          كل ما يحتاج انتباهك: حسابات بانتظار التفعيل، رسائل دعم بانتظار الرد، وآخر التغييرات.
        </p>
      </div>

      {/* Needs action */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-5">
          <div className="flex items-center gap-2 text-[#FFA726]">
            <UserPlus size={18} />
            <span className="text-sm font-bold">حسابات محتاجة تفعيل</span>
          </div>
          <p className="mt-2 text-3xl font-bold tabular-nums text-[#E0E0E0]">
            {pending.length}
          </p>
        </div>
        <div className="rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-5">
          <div className="flex items-center gap-2 text-[#4CAF50]">
            <MessageCircle size={18} />
            <span className="text-sm font-bold">رسائل محتاجة رد</span>
          </div>
          <p className="mt-2 text-3xl font-bold tabular-nums text-[#E0E0E0]">
            {threads.length}
          </p>
        </div>
      </div>

      {/* Pending accounts */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-[#E0E0E0]">حسابات بانتظار التفعيل</h2>
          <Link
            href="/users"
            className="flex items-center gap-1 text-xs text-[#D4AF37]"
          >
            إدارة المستخدمين <ArrowLeft size={14} />
          </Link>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E]">
          <div className="divide-y divide-[#2A2A2A]">
            {pending.length > 0 ? (
              pending.map((p) => (
                <Link
                  key={p.id}
                  href={`/users/${p.id}`}
                  className="flex items-center gap-3 p-4 transition-colors hover:bg-[#252525]"
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#FFA726]/15 text-[#FFA726]">
                    <UserPlus size={18} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold text-[#E0E0E0]">
                      {p.display_name || `مستخدم (${p.id.slice(0, 6)})`}
                    </p>
                    <p className="text-xs text-[#9E9E9E]">{timeAgo(p.created_at)}</p>
                  </div>
                  <span className="text-xs text-[#D4AF37]">تفعيل ←</span>
                </Link>
              ))
            ) : (
              <div className="p-8 text-center text-[#9E9E9E]">
                لا توجد طلبات تفعيل حالياً
              </div>
            )}
          </div>
        </div>
      </section>

      {/* Support threads needing reply */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="font-bold text-[#E0E0E0]">رسائل دعم بانتظار الرد</h2>
          <Link
            href="/support"
            className="flex items-center gap-1 text-xs text-[#D4AF37]"
          >
            صندوق الدعم <ArrowLeft size={14} />
          </Link>
        </div>
        <div className="overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E]">
          <div className="divide-y divide-[#2A2A2A]">
            {threads.length > 0 ? (
              threads.map((t) => {
                const profile = (t as { profiles?: { display_name?: string } })
                  .profiles;
                return (
                  <Link
                    key={t.id}
                    href={`/support/${t.id}`}
                    className="flex items-center gap-3 p-4 transition-colors hover:bg-[#252525]"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#4CAF50]/15 text-[#4CAF50]">
                      <MessageCircle size={18} />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-semibold text-[#E0E0E0]">
                        {profile?.display_name || 'مستخدم'}
                      </p>
                      {t.last_message_at && (
                        <p className="text-xs text-[#9E9E9E]">
                          {timeAgo(t.last_message_at)}
                        </p>
                      )}
                    </div>
                    <span className="rounded-full bg-[#800020] px-2 py-0.5 text-xs font-bold text-white">
                      {t.unread_admin} جديد
                    </span>
                  </Link>
                );
              })
            ) : (
              <div className="p-8 text-center text-[#9E9E9E]">
                لا توجد رسائل بانتظار الرد
              </div>
            )}
          </div>
        </div>
      </section>

      {/* Recent activity */}
      <section className="space-y-3">
        <h2 className="font-bold text-[#E0E0E0]">آخر التغييرات</h2>
        <div className="overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E]">
          <div className="divide-y divide-[#2A2A2A]">
            {audit.length > 0 ? (
              audit.map((a) => {
                const profile = (a as { profiles?: { display_name?: string } })
                  .profiles;
                return (
                  <div key={a.id} className="flex items-center gap-3 p-4">
                    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-[#2196F3]/15 text-[#2196F3]">
                      <Activity size={16} />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm text-[#E0E0E0]">
                        {actionLabels[a.action] || a.action}
                      </p>
                      <p className="text-xs text-[#9E9E9E]">
                        {profile?.display_name || 'النظام'} • {timeAgo(a.created_at)}
                      </p>
                    </div>
                  </div>
                );
              })
            ) : (
              <div className="p-8 text-center text-[#9E9E9E]">لا يوجد نشاط حديث</div>
            )}
          </div>
        </div>
      </section>
    </div>
  );
}
