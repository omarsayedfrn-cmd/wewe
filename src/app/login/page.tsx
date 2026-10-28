'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Shown when the middleware redirects an authenticated non-admin here.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('error') === 'forbidden') {
      setError('هذا الحساب ليس حساب إدارة');
    }
  }, []);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const supabase = createClient();
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError) throw signInError;

      // The dashboard is admin-only. Never auto-promote: verify the role and
      // sign the user back out if they are not an admin.
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user!.id)
        .maybeSingle();

      if (profile?.role !== 'admin') {
        await supabase.auth.signOut();
        throw new Error('هذا الحساب ليس حساب إدارة');
      }

      router.push('/');
      router.refresh();
    } catch (err: unknown) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('حدث خطأ أثناء تسجيل الدخول');
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center -m-6 bg-gradient-to-b from-[#5C0017] to-[#121212] p-4">
      <div className="w-full max-w-md bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-8 shadow-2xl">
        <div className="flex flex-col items-center mb-6">
          <div className="w-16 h-16 bg-[#800020] rounded-2xl flex items-center justify-center mb-3 shadow-lg">
            <span className="text-[#D4AF37] text-3xl font-bold">S</span>
          </div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">Solver Admin</h1>
          <p className="text-[#9E9E9E] text-sm mt-1">تسجيل الدخول إلى لوحة الإدارة</p>
        </div>

        {error && (
          <div className="bg-[#CF6679]/20 border border-[#CF6679]/40 text-[#CF6679] text-sm p-3 rounded-lg mb-4 text-center">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">البريد الإلكتروني</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2.5 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0] focus:outline-none focus:border-[#D4AF37]"
              placeholder="admin@solver.com"
            />
          </div>

          <div>
            <label className="block text-sm text-[#E0E0E0] mb-1">كلمة المرور</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2.5 bg-[#2A2A2A] border border-[#3A3A3A] rounded-xl text-[#E0E0E0] focus:outline-none focus:border-[#D4AF37]"
              placeholder="••••••••"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-[#800020] hover:bg-[#A0334A] text-white font-semibold rounded-xl transition duration-200 shadow-md flex items-center justify-center"
          >
            {loading ? 'جاري الدخول...' : 'تسجيل الدخول'}
          </button>
        </form>

        <p className="text-center text-xs text-[#9E9E9E] mt-6">
          Developed by Omar Sayed
        </p>
      </div>
    </div>
  );
}
