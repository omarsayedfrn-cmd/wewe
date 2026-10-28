'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { DollarSign, Check } from 'lucide-react';

export function PricingTable({
  pricing,
  engines,
}: {
  pricing: any[];
  engines: any[];
}) {
  const router = useRouter();
  const [costs, setCosts] = useState<Record<string, number>>(() => {
    const map: Record<string, number> = {};
    pricing.forEach((p) => {
      map[`${p.engine_code}_${p.kind}`] = p.cost;
    });
    return map;
  });
  const [savingKey, setSavingKey] = useState<string | null>(null);
  const [successKey, setSuccessKey] = useState<string | null>(null);

  async function handleSave(engineCode: string, kind: string) {
    const key = `${engineCode}_${kind}`;
    setSavingKey(key);
    setSuccessKey(null);

    try {
      const res = await fetch('/api/admin/update-pricing', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          engineCode,
          kind,
          cost: Number(costs[key]),
        }),
      });

      if (!res.ok) throw new Error('فشل تحديث السعر');

      setSuccessKey(key);
      router.refresh();
      setTimeout(() => setSuccessKey(null), 2500);
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSavingKey(null);
    }
  }

  const engineMap = new Map(engines.map((e) => [e.code, e]));

  return (
    <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl overflow-hidden shadow-lg">
      <div className="overflow-x-auto">
        <table className="w-full text-right text-sm">
          <thead className="bg-[#2A2A2A] text-[#E0E0E0] border-b border-[#3A3A3A]">
            <tr>
              <th className="p-4">المحرك</th>
              <th className="p-4">النطاق</th>
              <th className="p-4">السعر بالعملات</th>
              <th className="p-4 text-center">إجراءات</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[#2A2A2A]">
            {pricing.map((p) => {
              const key = `${p.engine_code}_${p.kind}`;
              const eng = engineMap.get(p.engine_code);

              return (
                <tr key={key} className="hover:bg-[#252525]">
                  <td className="p-4">
                    <div className="font-semibold text-[#E0E0E0]">
                      {eng?.name_ar || p.engine_code}
                    </div>
                    <div className="text-xs font-mono text-[#D4AF37]">{p.engine_code}</div>
                  </td>
                  <td className="p-4">
                    <span className="px-2.5 py-1 bg-[#800020]/20 text-[#D4AF37] rounded-lg text-xs font-medium">
                      المحرك بالكامل (Full)
                    </span>
                  </td>
                  <td className="p-4">
                    <div className="flex items-center gap-2">
                      <input
                        type="number"
                        min="0"
                        value={costs[key] ?? p.cost}
                        onChange={(e) =>
                          setCosts({
                            ...costs,
                            [key]: parseInt(e.target.value, 10) || 0,
                          })
                        }
                        className="w-28 px-3 py-1.5 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0] font-bold focus:border-[#D4AF37] outline-none"
                      />
                      <span className="text-xs text-[#9E9E9E]">عملة</span>
                    </div>
                  </td>
                  <td className="p-4 text-center">
                    <button
                      onClick={() => handleSave(p.engine_code, p.kind)}
                      disabled={savingKey === key}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#800020] hover:bg-[#A0334A] text-white rounded-lg transition-colors text-xs font-semibold disabled:opacity-50"
                    >
                      {successKey === key ? (
                        <>
                          <Check size={14} className="text-[#4CAF50]" />
                          تم الحفظ
                        </>
                      ) : savingKey === key ? (
                        'جاري الحفظ...'
                      ) : (
                        'حفظ السعر'
                      )}
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
