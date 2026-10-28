'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Plus, Package } from 'lucide-react';

export function ProductsManager({ products }: { products: any[] }) {
  const router = useRouter();
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

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || 'فشل إضافة الباقة');
      }

      setOpen(false);
      setName('');
      router.refresh();
    } catch (err: any) {
      alert(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">باقات العملات</h1>
          <p className="text-sm text-[#9E9E9E] mt-1">
            إدارة الباقات المعروضة للطلاب في التطبيق
          </p>
        </div>

        <button
          onClick={() => setOpen(true)}
          className="flex items-center gap-2 px-4 py-2.5 bg-[#800020] hover:bg-[#A0334A] text-white rounded-xl text-sm font-semibold transition-colors shadow-md"
        >
          <Plus size={16} />
          إضافة باقة جديدة
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {products.map((p) => (
          <div
            key={p.id}
            className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-6 relative overflow-hidden"
          >
            <div className="flex items-center justify-between mb-4">
              <span className="text-xs bg-[#D4AF37]/20 text-[#D4AF37] px-2.5 py-1 rounded-full font-mono">
                ترتيب: {p.sort}
              </span>
              <span
                className={`text-xs px-2.5 py-0.5 rounded-full ${
                  p.active
                    ? 'bg-[#4CAF50]/20 text-[#4CAF50]'
                    : 'bg-[#CF6679]/20 text-[#CF6679]'
                }`}
              >
                {p.active ? 'نشطة' : 'معطلة'}
              </span>
            </div>

            <h3 className="text-lg font-bold text-[#E0E0E0] mb-2">{p.name}</h3>

            <div className="flex items-baseline gap-2 mb-4">
              <span className="text-3xl font-extrabold text-[#D4AF37]">
                {p.coins}
              </span>
              <span className="text-sm text-[#9E9E9E]">عملة</span>
            </div>

            <div className="pt-4 border-t border-[#2A2A2A] flex justify-between items-center">
              <span className="text-sm text-[#9E9E9E]">السعر بالجنيه:</span>
              <span className="font-bold text-lg text-[#E0E0E0]">
                {p.price} ج.م
              </span>
            </div>
          </div>
        ))}
      </div>

      {open && (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl w-full max-w-md p-6">
            <h3 className="text-lg font-bold text-[#D4AF37] mb-4">إضافة باقة عملات</h3>
            <form onSubmit={handleAddProduct} className="space-y-4">
              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">اسم الباقة</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                  placeholder="مثال: الباقة الأساسية"
                />
              </div>

              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">عدد العملات</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={coins}
                  onChange={(e) => setCoins(parseInt(e.target.value, 10))}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                />
              </div>

              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">السعر (ج.م)</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={price}
                  onChange={(e) => setPrice(parseFloat(e.target.value))}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                />
              </div>

              <div>
                <label className="block text-sm text-[#E0E0E0] mb-1">الترتيب</label>
                <input
                  type="number"
                  value={sort}
                  onChange={(e) => setSort(parseInt(e.target.value, 10))}
                  className="w-full px-3 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  className="px-4 py-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl text-sm"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="px-4 py-2 bg-[#800020] hover:bg-[#A0334A] text-white rounded-xl text-sm font-semibold"
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
