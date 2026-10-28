'use client';

import { useState } from 'react';
import { Plus } from 'lucide-react';

export function ProductsManager({ products }: { products: any[] }) {
  const [items, setItems] = useState<any[]>(products);
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [coins, setCoins] = useState<number>(100);
  const [price, setPrice] = useState<number>(50);
  const [sort, setSort] = useState<number>(1);
  const [loading, setLoading] = useState(false);

  async function handleAddProduct(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);

    try {
      const res = await fetch('/api/admin/products', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          coins: Number(coins),
          price: Number(price),
          sort: Number(sort),
          active: true,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل إضافة الباقة');

      // Append the created product immediately — no full page re-render needed.
      if (data.data) {
        setItems((prev) =>
          [...prev, data.data].sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
        );
      }

      setOpen(false);
      setName('');
    } catch (err: any) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">باقات العملات</h1>
          <p className="mt-1 text-sm text-[#9E9E9E]">
            إدارة الباقات المعروضة للطلاب في التطبيق
          </p>
        </div>

        <button
          onClick={() => setOpen(true)}
          className="flex touch-manipulation items-center justify-center gap-2 rounded-xl bg-[#800020] px-4 py-2.5 text-sm font-semibold text-white shadow-md transition-colors hover:bg-[#A0334A] active:scale-95"
        >
          <Plus size={16} />
          إضافة باقة جديدة
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:gap-6 md:grid-cols-2 lg:grid-cols-3">
        {items.map((p) => (
          <div
            key={p.id}
            className="relative overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-5 sm:p-6"
          >
            <div className="mb-4 flex items-center justify-between gap-2">
              <span className="rounded-full bg-[#D4AF37]/20 px-2.5 py-1 font-mono text-xs text-[#D4AF37]">
                ترتيب: {p.sort}
              </span>
              <span
                className={`rounded-full px-2.5 py-0.5 text-xs ${
                  p.active
                    ? 'bg-[#4CAF50]/20 text-[#4CAF50]'
                    : 'bg-[#CF6679]/20 text-[#CF6679]'
                }`}
              >
                {p.active ? 'نشطة' : 'معطلة'}
              </span>
            </div>

            <h3 className="mb-2 text-lg font-bold text-[#E0E0E0]">{p.name}</h3>

            <div className="mb-4 flex items-baseline gap-2">
              <span className="text-3xl font-extrabold text-[#D4AF37]">
                {p.coins}
              </span>
              <span className="text-sm text-[#9E9E9E]">عملة</span>
            </div>

            <div className="flex items-center justify-between border-t border-[#2A2A2A] pt-4">
              <span className="text-sm text-[#9E9E9E]">السعر بالجنيه:</span>
              <span className="text-lg font-bold text-[#E0E0E0]">
                {p.price} ج.م
              </span>
            </div>
          </div>
        ))}
      </div>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
          <div className="max-h-[90dvh] w-full max-w-md overflow-y-auto rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] p-6">
            <h3 className="mb-4 text-lg font-bold text-[#D4AF37]">
              إضافة باقة عملات
            </h3>
            <form onSubmit={handleAddProduct} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm text-[#E0E0E0]">
                  اسم الباقة
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-2 text-[#E0E0E0]"
                  placeholder="مثال: الباقة الأساسية"
                />
              </div>

              <div>
                <label className="mb-1 block text-sm text-[#E0E0E0]">
                  عدد العملات
                </label>
                <input
                  type="number"
                  required
                  min="1"
                  value={coins}
                  onChange={(e) => setCoins(parseInt(e.target.value, 10))}
                  className="w-full rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-2 text-[#E0E0E0]"
                />
              </div>

              <div>
                <label className="mb-1 block text-sm text-[#E0E0E0]">
                  السعر (ج.م)
                </label>
                <input
                  type="number"
                  required
                  min="1"
                  value={price}
                  onChange={(e) => setPrice(parseFloat(e.target.value))}
                  className="w-full rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-2 text-[#E0E0E0]"
                />
              </div>

              <div>
                <label className="mb-1 block text-sm text-[#E0E0E0]">
                  الترتيب
                </label>
                <input
                  type="number"
                  value={sort}
                  onChange={(e) => setSort(parseInt(e.target.value, 10))}
                  className="w-full rounded-xl border border-[#3A3A3A] bg-[#2A2A2A] px-3 py-2 text-[#E0E0E0]"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  className="rounded-xl bg-[#2A2A2A] px-4 py-2 text-sm text-[#E0E0E0] hover:bg-[#353535]"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="rounded-xl bg-[#800020] px-4 py-2 text-sm font-semibold text-white hover:bg-[#A0334A] disabled:opacity-50"
                >
                  {loading ? 'جاري الإضافة...' : 'إضافة'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}