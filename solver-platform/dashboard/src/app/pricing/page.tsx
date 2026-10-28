import { createAdminClient } from '@/lib/supabase/server';
import { PricingTable } from '@/components/pricing-table';

export const dynamic = 'force-dynamic';

export default async function PricingPage() {
  const supabase = await createAdminClient();

  const [pricingRes, enginesRes] = await Promise.all([
    supabase.from('pricing').select('*').order('engine_code'),
    supabase.from('engines').select('*'),
  ]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-[#D4AF37]">أسعار فتح المحركات</h1>
        <p className="text-sm text-[#9E9E9E] mt-1">
          تعديل سعر فتح المحرك بالكامل بالعملات (تنعكس فوراً في التطبيق). الأسعار لكل فصل لم تعد تُستخدم.
        </p>
      </div>

      <PricingTable
        pricing={(pricingRes.data || []).filter((p: any) => p.kind === 'full')}
        engines={enginesRes.data || []}
      />
    </div>
  );
}
