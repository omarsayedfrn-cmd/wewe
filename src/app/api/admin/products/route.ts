import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient, getAdminUser } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { name, coins, price, active, sort } = await req.json();

    if (!name || typeof coins !== 'number' || typeof price !== 'number') {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    // Service role: the products table has no admin write RLS policy.
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
