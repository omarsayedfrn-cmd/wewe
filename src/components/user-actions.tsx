'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { PlusCircle, Key } from 'lucide-react';

export function UserActions({ userId, engines }: { userId: string; engines: any[] }) {
  const router = useRouter();

  // Coins Modal State
  const [coinsOpen, setCoinsOpen] = useState(false);
  const [coinsAmount, setCoinsAmount] = useState<number>(100);
  const [coinsNote, setCoinsNote] = useState('شحن يدوي');
  const [coinsLoading, setCoinsLoading] = useState(false);

  // Entitlement Modal State
  const [entOpen, setEntOpen] = useState(false);
  const [selectedEngine, setSelectedEngine] = useState(engines[0]?.code || '');
  const [entLoading, setEntLoading] = useState(false);

  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);

  async function handleGrantCoins(e: React.FormEvent) {
    e.preventDefault();
    setCoinsLoading(true);
    setMessage(null);

    try {
      const res = await fetch('/api/admin/grant-coins', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          amount: Number(coinsAmount),
          note: coinsNote,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل إضافة الرصيد');

      setMessage({ text: 'تم شحن الرصيد بنجاح' });
      setCoinsOpen(false);
      router.refresh();
    } catch (err: any) {
      setMessage({ text: err.message, error: true });
    } finally {
      setCoinsLoading(false);
    }
  }

  async function handleSetEntitlement(e: React.FormEvent) {
    e.preventDefault();
    setEntLoading(true);
    setMessage(null);

    try {
      const res = await fetch('/api/admin/set-entitlement', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          engineCode: selectedEngine,
          scope: 'full',
          chapters: [],
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل منح الصلاحية');

      setMessage({ text: 'تم منح صلاحية المحرك بنجاح' });
      setEntOpen(false);
      router.refresh();
    } catch (err: any) {
      setMessage({ text: err.message, error: true });
    } finally {
      setEntLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      {message && (
        <div
          className={`p-3 rounded-xl text-sm ${
            message.error
              ? 'bg-[#CF6679]/20 text-[#CF6679] border border-[#CF6679]/40'
              : 'bg-[#4CAF50]/20 text-[#4CAF50] border border-[#4CAF50]/40'
          }`}
        >
          {message.text}
        </div>
      )}

      <div className="flex flex-col gap-3 sm:flex-row">
        <button
          onClick={() => setCoinsOpen(true)}
          className="flex touch-manipulation items-center justify-center gap-2 rounded-xl bg-[#800020] px-4 py-2.5 text-sm font-semibold text-white shadow-md transition-colors hover:bg-[#A0334A] active:scale-95"
        >
          <PlusCircle size={16} />
          شحن عملات
        </button>

        <button
          onClick={() => setEntOpen(true)}
          className="flex touch-manipulation items-center justify-center gap-2 rounded-xl border border-[#D4AF37]/40 bg-[#2A2A2A] px-4 py-2.5 text-sm font-semibold text-[#D4AF37] shadow-md transition-colors hover:bg-[#353535] active:scale-95"
        >
          <Key size={16} />
          منح فتح كامل
        </button>
      </div>

      {/* Coins Modal */}
      {coinsOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl w-full max-w-md max-h-[90dvh] overflow-y-auto p-6">
            <h3 className="text-lg font-bold text-[#D4AF37] mb-4">شحن رصيد عملات</h3>
            <form onSubmit={handleGrantCoins} className="space-y-4">
              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">الكمية (عملات)</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={coinsAmount}
                  onChange={(e) => setCoinsAmount(parseInt(e.target.value, 10))}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                />
              </div>

              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">ملاحظة / سبب الشحن</label>
                <input
                  type="text"
                  value={coinsNote}
                  onChange={(e) => setCoinsNote(e.target.value)}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                  placeholder="مثلاً: تحويل فودافون كاش"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setCoinsOpen(false)}
                  className="px-4 py-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl text-sm"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  disabled={coinsLoading}
                  className="px-4 py-2 bg-[#800020] hover:bg-[#A0334A] text-white rounded-xl text-sm font-semibold"
                >
                  {coinsLoading ? 'جاري الشحن...' : 'تأكيد الشحن'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Entitlement Modal */}
      {entOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl w-full max-w-md max-h-[90dvh] overflow-y-auto p-6">
            <h3 className="text-lg font-bold text-[#D4AF37] mb-4">منح صلاحية محرك</h3>
            <form onSubmit={handleSetEntitlement} className="space-y-4">
              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">المحرك</label>
                <select
                  value={selectedEngine}
                  onChange={(e) => setSelectedEngine(e.target.value)}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                >
                  {engines.map((eng) => (
                    <option key={eng.code} value={eng.code}>
                      {eng.name_ar} ({eng.code})
                    </option>
                  ))}
                </select>
              </div>

              <p className="text-xs text-[#9E9E9E]">
                سيتم منح فتح المحرك بالكامل. التجربة المجانية تُمنح تلقائيًا للطالب حسب إعدادات الفصول التجريبية.
              </p>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEntOpen(false)}
                  className="px-4 py-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl text-sm"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  disabled={entLoading}
                  className="px-4 py-2 bg-[#D4AF37] hover:bg-[#B8941F] text-black rounded-xl text-sm font-semibold"
                >
                  {entLoading ? 'جاري المنح...' : 'تأكيد المنح'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
