import { createAdminClient } from '@/lib/supabase/server';
import { UsersTable, UserRow } from '@/components/users-table';

export const dynamic = 'force-dynamic';

export default async function UsersPage() {
  const supabase = await createAdminClient();

  // Fetch profiles with wallets and auth users
  const [profilesRes, authUsersRes] = await Promise.all([
    supabase
      .from('profiles')
      .select('*, wallets(balance), engine_access(count)')
      .order('created_at', { ascending: false }),
    supabase.auth.admin.listUsers({ perPage: 1000 }).catch(() => ({ data: { users: [] } })),
  ]);

  const profiles = profilesRes.data || [];
  const authUsers = authUsersRes.data?.users || [];

  // Create lookup for auth metadata
  const authMap = new Map(authUsers.map((u) => [u.id, u]));

  // Build unified user rows
  const userRows: UserRow[] = [];
  const processedIds = new Set<string>();

  // 1. Process profiles
  for (const p of profiles) {
    processedIds.add(p.id);
    const auth = authMap.get(p.id);

    // Extract phone
    let phone = (auth?.user_metadata?.phone as string) || '';
    if (!phone && p.display_name) {
      const match = p.display_name.match(/\((01[0-9]{9})\)/) || p.display_name.match(/(01[0-9]{9})/);
      if (match) phone = match[1];
    }
    if (!phone && auth?.email && auth.email.startsWith('user_')) {
      const digits = auth.email.replace('user_', '').replace('@solver.app', '');
      if (digits.length >= 9) phone = digits;
    }

    const balance = p.wallets?.[0]?.balance ?? p.wallets?.balance ?? 0;
    const enginesCount = p.engine_access?.[0]?.count ?? 0;

    // Determine pending status:
    // If student has 0 balance AND no engines granted yet, or onboard not locked
    const isPending = p.role === 'student' && balance === 0 && enginesCount === 0;

    userRows.push({
      id: p.id,
      display_name: p.display_name || auth?.user_metadata?.full_name || 'بدون اسم',
      role: p.role,
      grade: p.grade,
      track: p.track,
      language: p.language,
      referral_code: p.referral_code,
      balance,
      created_at: p.created_at,
      phone,
      is_pending: isPending,
    });
  }

  // 2. Add auth users that may not have a profile row yet (new registrations)
  for (const u of authUsers) {
    if (!processedIds.has(u.id)) {
      const phone = (u.user_metadata?.phone as string) ||
        (u.email?.startsWith('user_') ? u.email.replace('user_', '').replace('@solver.app', '') : '');

      userRows.push({
        id: u.id,
        display_name: u.user_metadata?.full_name || 'تسجيل جديد',
        role: 'student',
        grade: null,
        track: null,
        language: 'ar',
        referral_code: '—',
        balance: 0,
        created_at: u.created_at,
        phone,
        is_pending: true,
      });
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-[#D4AF37]">إدارة المستخدمين والطلاب</h1>
          <p className="text-sm text-[#9E9E9E] mt-1">
            متابعة الحسابات المسجلة، مراجعة وتفعيل طلبات الطلاب، والتواصل المباشر عبر WhatsApp.
          </p>
        </div>
      </div>

      <UsersTable initialUsers={userRows} />
    </div>
  );
}
