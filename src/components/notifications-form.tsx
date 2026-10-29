'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Send, Check } from 'lucide-react';

type UserOption = { id: string; display_name: string };

type AudienceType = 'all' | 'grade' | 'track' | 'language' | 'user';

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : 'فشل إرسال الإشعار';
}

const gradeOptions = [
  { value: 'grade_1', label: 'أولى ثانوي' },
  { value: 'grade_2', label: 'تانية ثانوي' },
];

const trackOptions = [
  { value: 'medicine', label: 'الطب والعلوم الحيوية' },
  { value: 'business', label: 'إدارة الأعمال' },
  { value: 'arts', label: 'الآداب والفنون' },
  { value: 'engineering', label: 'الهندسة وعلوم الحاسب' },
];

const languageOptions = [
  { value: 'ar', label: 'عام' },
  { value: 'en', label: 'لغات' },
];

const kindOptions = [
  { value: 'info', label: 'معلومة' },
  { value: 'success', label: 'نجاح' },
  { value: 'warning', label: 'تحذير' },
];

export function NotificationsForm({ users }: { users: UserOption[] }) {
  const router = useRouter();

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [kind, setKind] = useState('info');
  const [audienceType, setAudienceType] = useState<AudienceType>('all');
  const [audienceValue, setAudienceValue] = useState('');
  const [userId, setUserId] = useState('');

  const [sending, setSending] = useState(false);
  const [sent, setSent] = useState(false);
  const [message, setMessage] = useState<{
    text: string;
    error?: boolean;
  } | null>(null);

  function resetAudience() {
    setAudienceValue('');
    setUserId('');
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSending(true);
    setSent(false);
    setMessage(null);

    try {
      const audience =
        audienceType === 'user'
          ? { type: 'user', userId }
          : audienceType === 'all'
            ? { type: 'all' }
            : { type: audienceType, value: audienceValue };

      const res = await fetch('/api/admin/notifications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, body, kind, audience }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل إرسال الإشعار');

      setSent(true);
      setMessage({ text: `تم الإرسال إلى ${data.recipients} مستخدم` });
      setTitle('');
      setBody('');
      router.refresh();
      setTimeout(() => setSent(false), 3000);
    } catch (err) {
      setMessage({ text: errorMessage(err), error: true });
    } finally {
      setSending(false);
    }
  }

  const inputClass =
    'w-full px-3.5 py-2 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0]';

  return (
    <form onSubmit={handleSubmit} className="space-y-6 max-w-2xl">
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6 space-y-4">
        <h3 className="font-bold text-[#D4AF37]">إرسال إشعار جديد</h3>

        {/* Audience */}
        <div>
          <label className="block text-sm text-[#E0E0E0] mb-1">
            المستلمون
          </label>
          <select
            value={audienceType}
            onChange={(e) => {
              setAudienceType(e.target.value as AudienceType);
              resetAudience();
            }}
            className={inputClass}
          >
            <option value="all">كل المستخدمين</option>
            <option value="grade">مرحلة دراسية</option>
            <option value="track">مسار</option>
            <option value="language">لغة</option>
            <option value="user">مستخدم محدد</option>
          </select>
        </div>

        {audienceType === 'grade' && (
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              المرحلة
            </label>
            <select
              required
              value={audienceValue}
              onChange={(e) => setAudienceValue(e.target.value)}
              className={inputClass}
            >
              <option value="">اختر المرحلة</option>
              {gradeOptions.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
        )}

        {audienceType === 'track' && (
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">المسار</label>
            <select
              required
              value={audienceValue}
              onChange={(e) => setAudienceValue(e.target.value)}
              className={inputClass}
            >
              <option value="">اختر المسار</option>
              {trackOptions.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
        )}

        {audienceType === 'language' && (
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">اللغة</label>
            <select
              required
              value={audienceValue}
              onChange={(e) => setAudienceValue(e.target.value)}
              className={inputClass}
            >
              <option value="">اختر اللغة</option>
              {languageOptions.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </div>
        )}

        {audienceType === 'user' && (
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">
              المستخدم
            </label>
            <select
              required
              value={userId}
              onChange={(e) => setUserId(e.target.value)}
              className={inputClass}
            >
              <option value="">اختر المستخدم</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.display_name}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Title */}
        <div>
          <label className="block text-sm text-[#E0E0E0] mb-1">العنوان</label>
          <input
            required
            maxLength={120}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="مثال: تحديث جديد متاح"
            className={inputClass}
          />
        </div>

        {/* Body */}
        <div>
          <label className="block text-sm text-[#E0E0E0] mb-1">النص</label>
          <textarea
            required
            maxLength={1000}
            rows={4}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="اكتب نص الإشعار الذي سيظهر للطالب"
            className={`${inputClass} resize-y`}
          />
        </div>

        {/* Kind */}
        <div>
          <label className="block text-sm text-[#E0E0E0] mb-1">النوع</label>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className={inputClass}
          >
            {kindOptions.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>

        {message && (
          <p
            className={`text-sm ${
              message.error ? 'text-[#CF6679]' : 'text-[#4CAF50]'
            }`}
          >
            {message.text}
          </p>
        )}

        <button
          type="submit"
          disabled={sending}
          className="flex w-full touch-manipulation items-center justify-center gap-2 rounded-xl bg-[#800020] px-6 py-3 font-semibold text-white shadow-lg transition-colors hover:bg-[#A0334A] active:scale-[0.99] disabled:opacity-50 sm:w-auto"
        >
          {sent ? (
            <>
              <Check size={18} className="text-[#4CAF50]" />
              تم الإرسال
            </>
          ) : sending ? (
            'جاري الإرسال...'
          ) : (
            <>
              <Send size={18} />
              إرسال الإشعار
            </>
          )}
        </button>
      </div>
    </form>
  );
}
