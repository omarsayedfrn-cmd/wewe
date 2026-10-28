import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const { userId, engineCode, scope, chapters } = await req.json();

    if (!userId || !engineCode || !scope) {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    const supabase = await createAdminClient();

    const { error } = await supabase.rpc('admin_set_entitlement', {
      p_user_id: userId,
      p_engine_code: engineCode,
      p_scope: scope,
      p_chapters: chapters || [],
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
