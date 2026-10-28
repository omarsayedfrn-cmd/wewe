import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const { name, coins, price, active, sort } = await req.json();

    if (!name || typeof coins !== 'number' || typeof price !== 'number') {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    const supabase = await createAdminClient();

    const { data, error } = await supabase.from('products').insert({
      name,
      coins,
      price,
      active: active ?? true,
      sort: sort ?? 0,
    }).select().single();

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ data });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
