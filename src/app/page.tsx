import { createAdminClient } from '@/lib/supabase/server';
import { Users, Wallet, MessageCircle, Rocket, AlertTriangle, Clock } from 'lucide-react';

export const dynamic = 'force-dynamic';

async function getStats() {
  const supabase = await createAdminClient();

  const [usersRes, walletsRes, threadsRes, enginesRes, pendingRes] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('wallets').select('balance'),
    supabase
      .from('support_threads')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'open'),
    supabase.from('engines').select('code', { count: 'exact', head: true }),
    supabase
      .from('profiles')
      .select('id, wallets(balance)')
      .eq('role', 'student'),
  ]);

  const totalBalance =
    walletsRes.data?.reduce((sum, w) => sum + (w.balance || 0), 0) ?? 0;

  const pendingUsers =
    pendingRes.data?.filter(
      (p: any) => (p.wallets?.[0]?.balance ?? p.wallets?.balance ?? 0) === 0
    ).length ?? 0;

  return {
    totalUsers: usersRes.count ?? 0,
    pendingUsers,
    totalBalance,
    openTickets: threadsRes.count ?? 0,
    totalEngines: enginesRes.count ?? 0,
  };
}

export default async function DashboardPage() {
  const isConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      !process.env.NEXT_PUBLIC_SUPABASE_URL.includes('your-project') &&
      !process.env.NEXT_PUBLIC_SUPABASE_URL.includes('placeholder')
  );

  let stats = { totalUsers: 0, pendingUsers: 0, totalBalance: 0, openTickets: 0, totalEngines: 0 };

  if (isConfigured) {
    try {
      stats = await getStats();
    } catch {
      // Supabase connection failed — fall back to zeros
    }
  }

  const cards = [
    {
      label: 'إجمالي المستخدمين',
      value: stats.totalUsers,
      icon: Users,
      color: '#D4AF37',
    },
    {
      label: 'طلبات قيد المراجعة',
      value: stats.pendingUsers,
      icon: Clock,
      color: '#FF9800',
    },
    {
      label: 'إجمالي العملات',
      value: stats.totalBalance,
      icon: Wallet,
      color: '#4CAF50',
    },
    {
      label: 'تذاكر مفتوحة',
      value: stats.openTickets,
      icon: MessageCircle,
      color: '#800020',
    },
    {
      label: 'المحركات',
      value: stats.totalEngines,
      icon: Rocket,
      color: '#2196F3',
    },
  ];

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-[#D4AF37]">لوحة التحكم</h1>
      </div>

      {!isConfigured && (
        <div className="mb-6 p-4 bg-[#D4AF37]/10 border border-[#D4AF37]/30 rounded-2xl flex items-start gap-3">
          <AlertTriangle className="text-[#D4AF37] shrink-0 mt-0.5" size={20} />
          <div className="text-sm">
            <p className="font-bold text-[#D4AF37]">تنبيه إعداد الاتصال بقاعدة البيانات</p>
            <p className="text-[#E0E0E0] mt-1">
              الداشبورد يعمل الآن بنجاح، ولكن يلزم وضع مفاتيح مشروع Supabase الخاص بك في ملف{' '}
              <code className="bg-[#1E1E1E] px-2 py-0.5 rounded text-[#D4AF37] font-mono">
                dashboard/.env.local
              </code>{' '}
              لربط البيانات الحية وجلب المستخدمين والمحافظ.
            </p>
          </div>
        </div>
      )}

      {/* Stats cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {cards.map((card) => {
          const Icon = card.icon;
          return (
            <div
              key={card.label}
              className="bg-[#1E1E1E] rounded-2xl p-6 border border-[#2A2A2A]"
            >
              <div className="flex items-center justify-between mb-4">
                <div
                  className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ backgroundColor: `${card.color}20` }}
                >
                  <Icon size={20} style={{ color: card.color }} />
                </div>
              </div>
              <p className="text-3xl font-bold text-[#E0E0E0]">{card.value}</p>
              <p className="text-sm text-[#9E9E9E] mt-1">{card.label}</p>
            </div>
          );
        })}
      </div>

      {/* Quick info */}
      <div className="bg-[#1E1E1E] rounded-2xl p-6 border border-[#2A2A2A]">
        <h2 className="text-lg font-semibold text-[#E0E0E0] mb-4">
          ملاحظات تشغيلية
        </h2>
        <div className="space-y-3 text-[#9E9E9E] text-sm">
          <p>
            • الشحن يدوي: المستخدم يرسل صورة الدفع في الدعم → الأدمن يعتمد
            ويضيف العملات من صفحة المستخدم
          </p>
          <p>• الاختيار الأكاديمي مقفول بعد التسجيل (لا يمكن تغييره)</p>
          <p>• المحركات تعمل على جهاز المستخدم محلياً (Android App)</p>
          <p>• الإجابات مشفرة داخل التطبيق (AES-GCM)</p>
        </div>
      </div>
    </div>
  );
}
