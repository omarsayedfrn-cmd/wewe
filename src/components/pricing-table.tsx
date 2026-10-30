'use client';

import { useState } from 'react';
import { Check } from 'lucide-react';

type Pricing = { engine_code: string; kind: string; cost: number };
type Engine = { code: string; name_ar?: string | null; name_en?: string | null };

export function PricingTable({
  pricing,
  engines,
}: {
  pricing: Pricing[];
  engines: Engine[];
}) {
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
      setTimeout(() => setSuccessKey(null), 2500);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'فشل تحديث السعر');
    } finally {
      setSavingKey(null);
    }
  }

  const engineMap = new Map(engines.map((e) => [e.code, e]));

  const saveButton = (engineCode: string, kind: string) => {
    const key = `${engineCode}_${kind}`;
    return (
      <button
        onClick={() => handleSave(engineCode, kind)}
        disabled={savingKey === key}
        className="inline-flex touch-manipulation items-center justify-center gap-1.5 rounded-lg bg-[#800020] px-3 py-2 text-xs font-semibold text-white transition-colors hover:bg-[#A0334A] active:scale-95 disabled:opacity-50"
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
    );
  };

  const costInput = (p: Pricing) => {
    const key = `${p.engine_code}_${p.kind}`;
    return (
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
          className="w-24 rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-1.5 font-bold text-[#E0E0E0] outline-none focus:border-[#D4AF37] sm:w-28"
        />
        <span className="text-xs text-[#9E9E9E]">عملة</span>
      </div>
    );
  };

  return (
    <div className="space-y-3">
      {/* Desktop table */}
      <div className="hidden overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] shadow-lg md:block">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[560px] text-right text-sm">
            <thead className="border-b border-[#3A3A3A] bg-[#2A2A2A] text-[#E0E0E0]">
              <tr>
                <th className="p-3 sm:p-4">المحرك</th>
                <th className="p-3 sm:p-4">النطاق</th>
                <th className="p-3 sm:p-4">السعر بالعملات</th>
                <th className="p-3 text-center sm:p-4">إجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2A2A2A]">
              {pricing.map((p) => {
                const key = `${p.engine_code}_${p.kind}`;
                const eng = engineMap.get(p.engine_code);
                return (
                  <tr key={key} className="hover:bg-[#252525]">
                    <td className="p-3 sm:p-4">
                      <div className="font-semibold text-[#E0E0E0]">
                        {eng?.name_ar || p.engine_code}
                      </div>
                      <div className="font-mono text-xs text-[#D4AF37]">
                        {p.engine_code}
                      </div>
                    </td>
                    <td className="p-3 sm:p-4">
                      <span className="rounded-lg bg-[#800020]/20 px-2.5 py-1 text-xs font-medium text-[#D4AF37]">
                        المحرك بالكامل (Full)
                      </span>
                    </td>
                    <td className="p-3 sm:p-4">{costInput(p)}</td>
                    <td className="p-3 text-center sm:p-4">
                      {saveButton(p.engine_code, p.kind)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Mobile cards */}
      <div className="space-y-3 md:hidden">
        {pricing.map((p) => {
          const key = `${p.engine_code}_${p.kind}`;
          const eng = engineMap.get(p.engine_code);
          return (
            <div
              key={key}
              className="rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-4 shadow-lg"
            >
              <div className="flex items-center justify-between gap-2">
                <div className="min-w-0">
                  <div className="truncate font-semibold text-[#E0E0E0]">
                    {eng?.name_ar || p.engine_code}
                  </div>
                  <div className="font-mono text-xs text-[#D4AF37]">
                    {p.engine_code}
                  </div>
                </div>
                <span className="shrink-0 rounded-lg bg-[#800020]/20 px-2.5 py-1 text-xs font-medium text-[#D4AF37]">
                  Full
                </span>
              </div>
              <div className="mt-3 flex items-center justify-between gap-2">
                {costInput(p)}
                {saveButton(p.engine_code, p.kind)}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
