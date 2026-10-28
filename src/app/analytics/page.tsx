import { createAdminClient } from '@/lib/supabase/server';
import { AnalyticsCharts } from '@/components/analytics-charts';

export const dynamic = 'force-dynamic';

export default async function AnalyticsPage() {
  const supabase = await createAdminClient();

  const [usersRes, txRes, entRes] = await Promise.all([
    supabase.from('profiles').select('created_at, grade, language'),
    supabase.from('wallet_transactions').select('created_at, delta, reason'),
    supabase.from('entitlements').select('created_at, engine_code, scope'),
  ]);

  const users = usersRes.data || [];
  const transactions = txRes.data || [];
  const entitlements = entRes.data || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">التحليلات والمؤشرات</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          إحصائيات الطلاب والعمليات وتوزيع استخدام المحركات
        </p>
      </div>

      <AnalyticsCharts
        users={users}
        transactions={transactions}
        entitlements={entitlements}
      />
    </div>
  );
}
