import { createAdminClient } from '@/lib/supabase/server';
import { languageLabels } from '@/lib/types';
import { Rocket } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function EnginesPage() {
  const supabase = await createAdminClient();

  const { data: engines, error } = await supabase
    .from('engines')
    .select('*')
    .order('code');

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">كتالوج المحركات</h1>
          <p className="text-sm text-[#9E9E9E] mt-1">
            المحركات الستة المعتمدة في الإصدار الأول
          </p>
        </div>
      </div>

      {error ? (
        <div className="bg-[#CF6679]/10 border border-[#CF6679]/30 text-[#CF6679] p-4 rounded-xl">
          فشل تحميل بيانات المحركات: {error.message}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {engines?.map((eng) => (
            <div
              key={eng.code}
              className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-5 sm:p-6 hover:border-[#800020]/50 transition-colors"
            >
              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 bg-[#800020]/20 rounded-xl flex items-center justify-center text-xl">
                  {eng.platform === 'qureo' ? (eng.course.includes('python') ? '🐍' : '💻') : '💰'}
                </div>
                <div>
                  <h3 className="font-bold text-[#E0E0E0]">{eng.name_ar}</h3>
                  <p className="text-xs text-[#D4AF37] font-mono">{eng.code}</p>
                </div>
              </div>

              <div className="space-y-2 text-sm text-[#9E9E9E] pt-2 border-t border-[#2A2A2A]">
                <div className="flex justify-between">
                  <span>الاسم الإنجليزي:</span>
                  <span className="text-[#E0E0E0]">{eng.name_en}</span>
                </div>
                <div className="flex justify-between">
                  <span>المنصة:</span>
                  <span className="text-[#E0E0E0] uppercase font-semibold">{eng.platform}</span>
                </div>
                <div className="flex justify-between">
                  <span>اللغة:</span>
                  <span className="text-[#E0E0E0]">{languageLabels[eng.language] || eng.language}</span>
                </div>
                <div className="flex justify-between">
                  <span>المنهج / الكورس:</span>
                  <span className="text-[#E0E0E0] font-mono text-xs">{eng.course}</span>
                </div>
                <div className="flex justify-between">
                  <span>أقصى عدد فصول:</span>
                  <span className="text-[#D4AF37] font-bold">{eng.max_chapter}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
