import { NextRequest, NextResponse } from 'next/server';
import { createAdminClient, getAdminUser } from '@/lib/supabase/server';

export async function POST(req: NextRequest) {
  try {
    const admin = await getAdminUser();
    if (!admin) {
      return NextResponse.json({ error: 'غير مصرح' }, { status: 401 });
    }

    const { threadId, body } = await req.json();

    if (!threadId || !body) {
      return NextResponse.json({ error: 'بيانات غير مكتملة' }, { status: 400 });
    }

    const supabase = await createAdminClient();

    // Insert support message
    const { data: msg, error: msgError } = await supabase
      .from('support_messages')
      .insert({
        thread_id: threadId,
        sender_role: 'admin',
        body,
      })
      .select()
      .single();

    if (msgError) {
      return NextResponse.json({ error: msgError.message }, { status: 500 });
    }

    // Update thread last_message_at and increment unread_user
    const { error: thError } = await supabase
      .from('support_threads')
      .update({
        last_message_at: new Date().toISOString(),
        unread_admin: 0,
      })
      .eq('id', threadId);

    if (thError) {
      return NextResponse.json({ error: thError.message }, { status: 500 });
    }

    return NextResponse.json({ success: true, message: msg });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
