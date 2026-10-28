import { createAdminClient } from '@/lib/supabase/server';
import { Shield } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function AuditPage() {
  const supabase = await createAdminClient();

  const { data: logs, error } = await supabase
    .from('audit_logs')
    .select('*, profiles(display_name, role)')
    .order('created_at', { ascending: false })
    .limit(100);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">سجل تدقيق الإدارة</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          سجل غير قابل للتعديل لكافة العمليات الحساسة (شحن رصيد، منح فصول، تعديلات إدارية)
        </p>
      </div>

      {error ? (
        <div className="bg-[#CF6679]/10 border border-[#CF6679]/30 text-[#CF6679] p-4 rounded-xl">
          فشل تحميل سجل التدقيق: {error.message}
        </div>
      ) : (
        <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
          <div className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-right text-sm">
              <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
                <tr>
                  <th className="p-4">الإجراء</th>
                  <th className="p-4">المسؤول (الأدمن)</th>
                  <th className="p-4">تفاصيل العملية (Payload)</th>
                  <th className="p-4">التوقيت</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#2A2A2A]">
                {logs && logs.length > 0 ? (
                  logs.map((log: any) => (
                    <tr key={log.id} className="hover:bg-[#252525]">
                      <td className="p-4">
                        <span className="px-2.5 py-1 bg-[#800020]/20 text-[#D4AF37] rounded-lg text-xs font-mono font-semibold">
                          {log.action}
                        </span>
                      </td>
                      <td className="p-4">
                        <div className="font-semibold text-[#E0E0E0]">
                          {log.profiles?.display_name || 'أدمن'}
                        </div>
                        <div className="text-xs font-mono text-[#9E9E9E]">
                          {log.admin_id.slice(0, 8)}...
                        </div>
                      </td>
                      <td className="p-4">
                        <pre className="text-xs bg-[#121212] p-2 rounded-lg font-mono text-[#E0E0E0] max-w-[220px] overflow-x-auto sm:max-w-md">
                          {JSON.stringify(log.payload, null, 2)}
                        </pre>
                      </td>
                      <td className="p-4 text-xs text-[#9E9E9E]">
                        {new Date(log.created_at).toLocaleString('ar-EG')}
                      </td>
                    </tr>
                  ))
                ) : (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-[#9E9E9E]">
                      لا توجد سجلات تدقيق حتى الآن
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
