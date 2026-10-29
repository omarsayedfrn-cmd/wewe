import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient, getAdminUser } from '@/lib/supabase/server';

type Audience =
  | { type: 'all' }
  | { type: 'grade'; value: string }
  | { type: 'track'; value: string }
  | { type: 'language'; value: string }
  | { type: 'user'; userId: string };

export async function POST(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { title, body, kind, audience } = await req.json();

    const cleanTitle = typeof title === 'string' ? title.trim() : '';
    const cleanBody = typeof body === 'string' ? body.trim() : '';

    if (!cleanTitle || !cleanBody) {
      return NextResponse.json(
        { error: 'العنوان والنص مطلوبان' },
        { status: 400 }
      );
    }

    if (cleanTitle.length > 120 || cleanBody.length > 1000) {
      return NextResponse.json(
        { error: 'العنوان أو النص طويل جدًا' },
        { status: 400 }
      );
    }

    const safeKind = ['info', 'warning', 'success'].includes(kind)
      ? kind
      : 'info';

    const supabase = await createAdminClient();

    // ── Resolve recipients ────────────────────────────────────────────────
    const aud: Audience = audience ?? { type: 'all' };
    let userIds: string[] = [];

    if (aud.type === 'user' && aud.userId) {
      userIds = [aud.userId];
    } else if (aud.type === 'grade' && aud.value) {
      const { data } = await supabase
        .from('profiles')
        .select('id')
        .eq('grade', aud.value);
      userIds = (data ?? []).map((r) => r.id);
    } else if (aud.type === 'track' && aud.value) {
      const { data } = await supabase
        .from('profiles')
        .select('id')
        .eq('track', aud.value);
      userIds = (data ?? []).map((r) => r.id);
    } else if (aud.type === 'language' && aud.value) {
      const { data } = await supabase
        .from('profiles')
        .select('id')
        .eq('language', aud.value);
      userIds = (data ?? []).map((r) => r.id);
    } else {
      // Everyone except admins.
      const { data } = await supabase
        .from('profiles')
        .select('id')
        .neq('role', 'admin');
      userIds = (data ?? []).map((r) => r.id);
    }

    if (userIds.length === 0) {
      return NextResponse.json(
        { error: 'لا يوجد مستلمون مطابقون' },
        { status: 400 }
      );
    }

    const broadcastId = crypto.randomUUID();

    const rows = userIds.map((uid) => ({
      user_id: uid,
      broadcast_id: broadcastId,
      title: cleanTitle,
      body: cleanBody,
      kind: safeKind,
      created_by: admin.user.id,
    }));

    // Insert in chunks so a big broadcast never exceeds the request size.
    const CHUNK = 500;
    for (let i = 0; i < rows.length; i += CHUNK) {
      const { error } = await supabase
        .from('notifications')
        .insert(rows.slice(i, i + CHUNK));

      if (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
      }
    }

    await supabase.from('audit_logs').insert({
      admin_id: admin.user.id,
      action: 'send_notification',
      payload: {
        title: cleanTitle,
        kind: safeKind,
        audience: aud.type,
        recipients: userIds.length,
      },
    });

    return NextResponse.json({ success: true, recipients: userIds.length });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'خطأ غير متوقع';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
