import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const { userId, amount, note } = await req.json();

    if (!userId || typeof amount !== 'number') {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    const supabase = await createAdminClient();

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
