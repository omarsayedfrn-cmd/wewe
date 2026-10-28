'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Save, Check } from 'lucide-react';

export function SettingsForm({ initialSettings }: { initialSettings: Record<string, any> }) {
  const router = useRouter();
  const [form, setForm] = useState({
    referral_signup_reward: initialSettings['referral_signup_reward'] ?? 10,
    referral_recharge_reward: initialSettings['referral_recharge_reward'] ?? 20,
    trial_chapters_grade1: initialSettings['trial_chapters_grade1'] ?? 5,
    trial_chapters_grade2_engineering: initialSettings['trial_chapters_grade2_engineering'] ?? 10,
    trial_chapters_grade2_other: initialSettings['trial_chapters_grade2_other'] ?? 1,
  });

  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setSaved(false);

    try {
      const res = await fetch('/api/admin/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ settings: form }),
      });

      if (!res.ok) throw new Error('فشل حفظ الإعدادات');

      setSaved(true);
      router.refresh();
      setTimeout(() => setSaved(false), 3000);
    } catch (err: any) {
      alert(err.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6 max-w-2xl">
      {/* Referral Rewards */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-6">
        <h3 className="font-bold text-[#D4AF37] mb-4">مكافآت الإحالة (Referral Rewards)</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              مكافأة عند التسجيل بالكود (عملات)
            </label>
            <input
              type="number"
              min="0"
              value={form.referral_signup_reward}
              onChange={(e) =>
                setForm({
                  ...form,
                  referral_signup_reward: parseInt(e.target.value, 10) || 0,
                })
              }
              className="w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
            />
          </div>

          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              مكافأة عند أول شحن للمُحال (عملات)
            </label>
            <input
              type="number"
              min="0"
              value={form.referral_recharge_reward}
              onChange={(e) =>
                setForm({
                  ...form,
                  referral_recharge_reward: parseInt(e.target.value, 10) || 0,
                })
              }
              className="w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
            />
          </div>
        </div>
      </div>

      {/* Trial Limits */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-6">
        <h3 className="font-bold text-[#D4AF37] mb-4">حدود التجربة المجانية (Trial Limits)</h3>
        <p className="text-xs text-[#9E9E9E] mb-4">
          عدد الفصول التي يحلها الطالب مجانًا مرة واحدة. القيمة 0 تعطّل التجربة.
        </p>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              أولى ثانوي (فصول QUREO مجانية)
            </label>
            <input
              type="number"
              min="0"
              max="54"
              value={form.trial_chapters_grade1}
              onChange={(e) =>
                setForm({
                  ...form,
                  trial_chapters_grade1: parseInt(e.target.value, 10) || 0,
                })
              }
              className="w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
            />
          </div>

          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              تانية ثانوي - هندسة وحاسب (فصول QUREO مجانية)
            </label>
            <input
              type="number"
              min="0"
              max="54"
              value={form.trial_chapters_grade2_engineering}
              onChange={(e) =>
                setForm({
                  ...form,
                  trial_chapters_grade2_engineering: parseInt(e.target.value, 10) || 0,
                })
              }
              className="w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
            />
          </div>

          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              باقي مسارات تانية ثانوي (فصول SPRIX مجانية)
            </label>
            <input
              type="number"
              min="0"
              max="54"
              value={form.trial_chapters_grade2_other}
              onChange={(e) =>
                setForm({
                  ...form,
                  trial_chapters_grade2_other: parseInt(e.target.value, 10) || 0,
                })
              }
              className="w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]"
            />
          </div>
        </div>
      </div>

      <button
        type="submit"
        disabled={saving}
        className="flex items-center gap-2 px-6 py-3 bg-[#800020] hover:bg-[#A0334A] text-white rounded-xl font-semibold transition-colors shadow-lg disabled:opacity-50"
      >
        {saved ? (
          <>
            <Check size={18} className="text-[#4CAF50]" />
            تم الحفظ بنجاح
          </>
        ) : saving ? (
          'جاري الحفظ...'
        ) : (
          <>
            <Save size={18} />
            حفظ التغييرات
          </>
        )}
      </button>
    </form>
  );
}
