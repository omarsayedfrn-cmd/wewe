import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const { engineCode, kind, cost } = await req.json();

    if (!engineCode || !kind || typeof cost !== 'number') {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    const supabase = await createAdminClient();

    const { error } = await supabase
      .from('pricing')
      .upsert({
        engine_code: engineCode,
        kind,
        cost,
      }, { onConflict: 'engine_code,kind' });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
