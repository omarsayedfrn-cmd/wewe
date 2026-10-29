'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { PlusCircle, Key, Unlink, CheckCircle, XCircle, Loader2, Store, GraduationCap } from 'lucide-react';

export function UserActions({
  userId,
  engines,
  platformLogin,
  approved,
  role,
}: {
  userId: string;
  engines: any[];
  platformLogin?: string | null;
  approved?: boolean;
  role?: string;
}) {
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

  // Unbind Account Modal State
  const [unbindOpen, setUnbindOpen] = useState(false);
  const [unbindLoading, setUnbindLoading] = useState(false);

  // Approval loading state
  const [approvalLoading, setApprovalLoading] = useState(false);

  // Role (merchant) state
  const [roleOpen, setRoleOpen] = useState(false);
  const [roleLoading, setRoleLoading] = useState(false);

  const [message, setMessage] = useState<{ text: string; error?: boolean } | null>(null);

  async function setApproval(next: boolean) {
    setApprovalLoading(true);
    setMessage(null);

    try {
      const res = await fetch('/api/admin/set-approval', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, approved: next }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل تحديث حالة الحساب');

      setMessage({ text: next ? 'تم تفعيل الحساب' : 'تم تعليق الحساب' });
      router.refresh();
    } catch (err: any) {
      setMessage({ text: err.message, error: true });
    } finally {
      setApprovalLoading(false);
    }
  }

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

  async function handleUnbind() {
    setUnbindLoading(true);
    setMessage(null);

    try {
      const res = await fetch('/api/admin/unbind-account', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل فك الربط');

      setMessage({ text: 'تم فك ربط الحساب بنجاح' });
      setUnbindOpen(false);
      router.refresh();
    } catch (err: any) {
      setMessage({ text: err.message, error: true });
    } finally {
      setUnbindLoading(false);
    }
  }

  const isMerchant = role === 'merchant';
  const canManageRole = role === 'student' || role === 'merchant';

  async function handleSetRole() {
    setRoleLoading(true);
    setMessage(null);

    try {
      const res = await fetch('/api/admin/set-role', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          role: isMerchant ? 'student' : 'merchant',
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل تحديث دور الحساب');

      setMessage({ text: isMerchant ? 'تم تحويل الحساب إلى طالب' : 'تمت ترقية الحساب إلى تاجر' });
      setRoleOpen(false);
      router.refresh();
    } catch (err: any) {
      setMessage({ text: err.message, error: true });
    } finally {
      setRoleLoading(false);
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
        {role === 'student' && (
          <button
            onClick={() => setApproval(!approved)}
            disabled={approvalLoading}
            className={`flex touch-manipulation items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold text-white shadow-md transition-colors active:scale-95 disabled:opacity-60 ${
              approved
                ? 'bg-[#CF6679] hover:bg-[#b85566]'
                : 'bg-[#4CAF50] hover:bg-[#43a047]'
            }`}
          >
            {approvalLoading ? (
              <Loader2 size={16} className="animate-spin" />
            ) : approved ? (
              <XCircle size={16} />
            ) : (
              <CheckCircle size={16} />
            )}
            {approved ? 'تعليق الحساب' : 'تفعيل الحساب'}
          </button>
        )}

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

        {canManageRole && (
          <button
            onClick={() => setRoleOpen(true)}
            className="flex touch-manipulation items-center justify-center gap-2 rounded-xl border border-[#4CAF50]/40 bg-[#2A2A2A] px-4 py-2.5 text-sm font-semibold text-[#4CAF50] shadow-md transition-colors hover:bg-[#353535] active:scale-95"
          >
            {isMerchant ? <GraduationCap size={16} /> : <Store size={16} />}
            {isMerchant ? 'تحويل لطالب' : 'ترقية لتاجر'}
          </button>
        )}

        {platformLogin && (
          <button
            onClick={() => setUnbindOpen(true)}
            className="flex touch-manipulation items-center justify-center gap-2 rounded-xl border border-[#CF6679]/40 bg-[#2A2A2A] px-4 py-2.5 text-sm font-semibold text-[#CF6679] shadow-md transition-colors hover:bg-[#353535] active:scale-95"
          >
            <Unlink size={16} />
            فك ربط الحساب
          </button>
        )}
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

      {/* Unbind Account Modal */}
      {unbindOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl w-full max-w-md max-h-[90dvh] overflow-y-auto p-6">
            <h3 className="text-lg font-bold text-[#D4AF37] mb-4">فك ربط حساب المنصة</h3>
            <p className="text-sm text-[#E0E0E0] leading-relaxed">
              الحساب المربوط:{' '}
              <span className="font-mono font-bold text-[#D4AF37]" dir="ltr">
                {platformLogin}
              </span>
            </p>
            <p className="text-xs text-[#9E9E9E] mt-3 leading-relaxed">
              بعد فك الربط يقدر الطالب يربط حسابًا آخر، لكن الاشتراكات الحالية تفضل مملوكة للحساب القديم، وأي حساب جديد محتاج شراء جديد. تأكد من أن الطالب على علم بذلك.
            </p>
            <div className="flex justify-end gap-2 pt-4">
              <button
                type="button"
                onClick={() => setUnbindOpen(false)}
                className="px-4 py-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl text-sm"
              >
                إلغاء
              </button>
              <button
                type="button"
                onClick={handleUnbind}
                disabled={unbindLoading}
                className="px-4 py-2 bg-[#CF6679] hover:bg-[#b85566] text-white rounded-xl text-sm font-semibold"
              >
                {unbindLoading ? 'جاري الفك...' : 'تأكيد فك الربط'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Role Modal */}
      {roleOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 flex items-center justify-center p-4">
          <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl w-full max-w-md max-h-[90dvh] overflow-y-auto p-6">
            <h3 className="text-lg font-bold text-[#D4AF37] mb-4">
              {isMerchant ? 'تحويل الحساب إلى طالب' : 'ترقية الحساب إلى تاجر'}
            </h3>
            <p className="text-sm text-[#E0E0E0] leading-relaxed">
              {isMerchant
                ? 'سيتم استرجاع دور الطالب وإعادة بناء المحركات المتاحة حسب المرحلة والمسار واللغة. أي محركات خارج نطاقه الأكاديمي ستُزال.'
                : 'سيتم منح الحساب دور تاجر مع الوصول لكل المحركات، وتفعيله تلقائياً، بدون تجربة مجانية وبدون إحالة. نفس نظام ربط الحساب والاشتراك يبقى كما هو.'}
            </p>
            <div className="flex justify-end gap-2 pt-4">
              <button
                type="button"
                onClick={() => setRoleOpen(false)}
                className="px-4 py-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl text-sm"
              >
                إلغاء
              </button>
              <button
                type="button"
                onClick={handleSetRole}
                disabled={roleLoading}
                className="px-4 py-2 bg-[#4CAF50] hover:bg-[#43a047] text-white rounded-xl text-sm font-semibold disabled:opacity-60"
              >
                {roleLoading ? 'جاري التحديث...' : 'تأكيد'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
