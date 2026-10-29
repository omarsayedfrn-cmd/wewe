import { createAdminClient } from '@/lib/supabase/server';
import { NotificationsForm } from '@/components/notifications-form';
import { Bell } from 'lucide-react';

export const dynamic = 'force-dynamic';

const kindLabels: Record<string, string> = {
  info: 'معلومة',
  success: 'نجاح',
  warning: 'تحذير',
};

const kindColors: Record<string, string> = {
  info: 'text-[#D4AF37]',
  success: 'text-[#4CAF50]',
  warning: 'text-[#FFA726]',
};

type BroadcastRow = {
  broadcast_id: string;
  title: string;
  body: string;
  kind: string;
  created_at: string;
  recipients: number;
};

export default async function NotificationsPage() {
  const supabase = await createAdminClient();

  const [recentRes, usersRes] = await Promise.all([
    supabase
      .from('notifications')
      .select('broadcast_id, title, body, kind, created_at')
      .order('created_at', { ascending: false })
      .limit(1000),
    supabase
      .from('profiles')
      .select('id, display_name')
      .neq('role', 'admin')
      .order('display_name', { ascending: true }),
  ]);

  type UserRow = { id: string; display_name: string | null };
  const users = ((usersRes.data ?? []) as UserRow[]).map((u) => ({
    id: u.id,
    display_name: u.display_name || `مستخدم (${u.id.slice(0, 6)})`,
  }));

  // Group fan-out rows back into one entry per broadcast.
  const groups = new Map<string, BroadcastRow>();
  const rows = (recentRes.data ?? []) as {
    broadcast_id: string;
    title: string;
    body: string;
    kind: string;
    created_at: string;
  }[];
  for (const row of rows) {
    const existing = groups.get(row.broadcast_id);
    if (existing) {
      existing.recipients += 1;
    } else {
      groups.set(row.broadcast_id, {
        broadcast_id: row.broadcast_id,
        title: row.title,
        body: row.body,
        kind: row.kind,
        created_at: row.created_at,
        recipients: 1,
      });
    }
  }
  const history = Array.from(groups.values()).slice(0, 30);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">الإشعارات</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          إرسال إشعارات فورية للطلاب داخل التطبيق ومتابعة آخر ما تم إرساله
        </p>
      </div>

      <NotificationsForm users={users} />

      <div className="space-y-3">
        <h2 className="font-bold text-[#E0E0E0]">آخر الإشعارات المُرسَلة</h2>

        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
          <div className="divide-y divide-[#2A2A2A]">
            {history.length > 0 ? (
              history.map((h) => (
                <div key={h.broadcast_id} className="flex gap-4 p-4 sm:p-5">
                  <div className="w-11 h-11 shrink-0 bg-[#800020]/20 rounded-2xl flex items-center justify-center text-[#D4AF37]">
                    <Bell size={20} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-bold text-[#E0E0E0]">
                        {h.title}
                      </span>
                      <span
                        className={`text-xs font-semibold ${
                          kindColors[h.kind] ?? 'text-[#9E9E9E]'
                        }`}
                      >
                        {kindLabels[h.kind] ?? h.kind}
                      </span>
                    </div>
                    <p className="text-sm text-[#9E9E9E] mt-1 whitespace-pre-wrap">
                      {h.body}
                    </p>
                    <p className="text-xs text-[#9E9E9E] mt-2">
                      {h.recipients} مستلم •{' '}
                      {new Date(h.created_at).toLocaleString('ar-EG')}
                    </p>
                  </div>
                </div>
              ))
            ) : (
              <div className="p-8 text-center text-[#9E9E9E]">
                لم يتم إرسال أي إشعارات حتى الآن
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
