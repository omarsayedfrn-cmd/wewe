import { NextRequest, NextResponse } from 'next/server';
import { getAdminUser } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { userId, amount, note } = await req.json();

    if (!userId || typeof amount !== 'number') {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    // Use the caller's session so auth.uid() is set — the RPC validates is_admin().
    const supabase = admin.supabase;

    const { error } = await supabase.rpc('admin_grant_coins', {
      p_user_id: userId,
      p_amount: amount,
      p_note: note || 'منحة من الإدارة',
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
