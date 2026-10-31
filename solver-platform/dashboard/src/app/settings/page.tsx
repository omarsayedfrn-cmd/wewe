import { createAdminClient } from '@/lib/supabase/server';
import { SettingsForm } from '@/components/settings-form';

export const dynamic = 'force-dynamic';

export default async function SettingsPage() {
  const supabase = await createAdminClient();

  const { data: settingsData } = await supabase.from('settings').select('*');

  const settingsMap: Record<string, any> = {};
  settingsData?.forEach((row) => {
    try {
      settingsMap[row.key] = typeof row.value === 'string' ? JSON.parse(row.value) : row.value;
    } catch {
      settingsMap[row.key] = row.value;
    }
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">إعدادات المنظومة</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          تعديل مكافآت الإحالة، حدود التجربة المجانية، وسياسة تحديث التطبيق الإجباري
        </p>
      </div>

      <SettingsForm initialSettings={settingsMap} />
    </div>
  );
}
