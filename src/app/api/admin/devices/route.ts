import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient, getAdminUser } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { token, platform } = await req.json();
    if (!token || typeof token !== 'string') {
      return NextResponse.json({ error: 'توكن غير صالح' }, { status: 400 });
    }

    const supabase = await createAdminClient();
    const { error } = await supabase.from('admin_devices').upsert(
      {
        admin_id: admin.user.id,
        token,
        platform: platform === 'ios' ? 'ios' : 'android',
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'token' }
    );

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'خطأ غير متوقع';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { token } = await req.json();
    if (!token || typeof token !== 'string') {
      return NextResponse.json({ error: 'توكن غير صالح' }, { status: 400 });
    }

    const supabase = await createAdminClient();
    const { error } = await supabase
      .from('admin_devices')
      .delete()
      .eq('token', token);

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'خطأ غير متوقع';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
