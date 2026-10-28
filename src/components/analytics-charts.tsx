'use client';

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  CartesianGrid,
} from 'recharts';

const COLORS = ['#800020', '#D4AF37', '#4CAF50', '#2196F3', '#9C27B0', '#FF9800'];

export function AnalyticsCharts({
  users,
  transactions,
  entitlements,
}: {
  users: any[];
  transactions: any[];
  entitlements: any[];
}) {
  // Aggregate engines usage
  const engineUsageMap: Record<string, number> = {};
  entitlements.forEach((e) => {
    engineUsageMap[e.engine_code] = (engineUsageMap[e.engine_code] || 0) + 1;
  });

  const engineData = Object.entries(engineUsageMap).map(([name, count]) => ({
    name,
    count,
  }));

  // Aggregate languages
  const langCount: Record<string, number> = { ar: 0, en: 0 };
  users.forEach((u) => {
    if (u.language === 'en') langCount.en += 1;
    else langCount.ar += 1;
  });

  const langData = [
    { name: 'عام (عربي)', value: langCount.ar || 1 },
    { name: 'لغات (إنجليزي)', value: langCount.en || 0 },
  ];

  // Aggregate revenue by reason
  const reasonMap: Record<string, number> = {};
  transactions
    .filter((t) => t.delta < 0) // Debits (purchases)
    .forEach((t) => {
      reasonMap[t.reason] = (reasonMap[t.reason] || 0) + Math.abs(t.delta);
    });

  const spendingData = Object.entries(reasonMap).map(([reason, amount]) => ({
    reason,
    amount,
  }));

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      {/* Engine Popularity */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
        <h3 className="font-bold text-[#D4AF37] mb-4">أكثر المحركات طلباً (Entitlements)</h3>
        <div className="h-56 sm:h-64">
          {engineData.length > 0 ? (
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={engineData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2A2A2A" />
                <XAxis dataKey="name" stroke="#9E9E9E" textAnchor="end" tick={{ fontSize: 11 }} />
                <YAxis stroke="#9E9E9E" />
                <Tooltip
                  contentStyle={{ backgroundColor: '#1E1E1E', borderColor: '#333' }}
                />
                <Bar dataKey="count" fill="#800020" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-full flex items-center justify-center text-sm text-[#9E9E9E]">
              لا توجد عمليات فتح مسجلة حتى الآن
            </div>
          )}
        </div>
      </div>

      {/* Language Distribution */}
      <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl p-4 sm:p-6">
        <h3 className="font-bold text-[#D4AF37] mb-4">توزيع طلاب (عام / لغات)</h3>
        <div className="h-56 sm:h-64 flex items-center justify-center">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={langData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={80}
                paddingAngle={5}
                dataKey="value"
              >
                {langData.map((_, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip
                contentStyle={{ backgroundColor: '#1E1E1E', borderColor: '#333' }}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>
        <div className="flex justify-center gap-6 text-xs text-[#9E9E9E] mt-2">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#800020]" />
            <span>عام: {langCount.ar}</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-[#D4AF37]" />
            <span>لغات: {langCount.en}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
