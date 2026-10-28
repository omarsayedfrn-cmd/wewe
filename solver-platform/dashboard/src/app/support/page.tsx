import Link from 'next/link';
import { createAdminClient } from '@/lib/supabase/server';
import { MessageCircle, User } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function SupportPage() {
  const supabase = await createAdminClient();

  const { data: threads, error } = await supabase
    .from('support_threads')
    .select('*, profiles(*)')
    .order('last_message_at', { ascending: false, nullsFirst: false });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">صندوق الدعم الفني</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          متابعة تذاكر ومحادثات شحن العملات واستفسارات الطلاب
        </p>
      </div>

      {error ? (
        <div className="bg-[#CF6679]/10 border border-[#CF6679]/30 text-[#CF6679] p-4 rounded-xl">
          فشل تحميل محادثات الدعم: {error.message}
        </div>
      ) : (
        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
          <div className="divide-y divide-[#2A2A2A]">
            {threads && threads.length > 0 ? (
              threads.map((th: any) => (
                <Link
                  key={th.id}
                  href={`/support/${th.id}`}
                  prefetch={false}
                  className="flex flex-col gap-3 p-4 transition-colors hover:bg-[#252525] sm:flex-row sm:items-center sm:justify-between sm:p-5"
                >
                  <div className="flex min-w-0 items-center gap-4">
                    <div className="w-12 h-12 shrink-0 bg-[#800020]/20 rounded-2xl flex items-center justify-center text-[#D4AF37]">
                      <MessageCircle size={22} />
                    </div>
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-bold text-[#E0E0E0]">
                          {th.profiles?.display_name || 'مستخدم بدون اسم'}
                        </span>
                        <span className="text-xs font-mono text-[#9E9E9E]">
                          ({th.user_id.slice(0, 8)}...)
                        </span>
                        {th.unread_admin > 0 && (
                          <span className="px-2 py-0.5 bg-[#800020] text-white text-xs font-bold rounded-full">
                            {th.unread_admin} جديد
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-[#9E9E9E] mt-1">
                        الحالة:{' '}
                        <span className={th.status === 'open' ? 'text-[#4CAF50]' : 'text-[#CF6679]'}>
                          {th.status === 'open' ? 'مفتوحة' : 'مغلقة'}
                        </span>
                        {th.last_message_at && (
                          <> • آخر رسالة: {new Date(th.last_message_at).toLocaleString('ar-EG')}</>
                        )}
                      </p>
                    </div>
                  </div>

                  <div className="self-start rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-1.5 text-xs font-semibold text-[#D4AF37] sm:self-auto">
                    فتح المحادثة ←
                  </div>
                </Link>
              ))
            ) : (
              <div className="p-8 text-center text-[#9E9E9E]">
                لا توجد محادثات دعم فني حتى الآن
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
