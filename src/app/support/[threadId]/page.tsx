import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createAdminClient } from '@/lib/supabase/server';
import { SupportChat } from '@/components/support-chat';
import { ArrowRight } from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function SupportThreadPage({
  params,
}: {
  params: Promise<{ threadId: string }>;
}) {
  const { threadId } = await params;
  const supabase = await createAdminClient();

  const [threadRes, messagesRes] = await Promise.all([
    supabase
      .from('support_threads')
      .select('*, profiles(*)')
      .eq('id', threadId)
      .single(),
    supabase
      .from('support_messages')
      .select('*')
      .eq('thread_id', threadId)
      .order('created_at', { ascending: true }),
  ]);

  if (threadRes.error || !threadRes.data) {
    notFound();
  }

  // Mark admin unread as 0
  await supabase
    .from('support_threads')
    .update({ unread_admin: 0 })
    .eq('id', threadId);

  const thread = threadRes.data;
  const messages = messagesRes.data || [];

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Link
          href="/support"
          className="p-2 bg-[#2A2A2A] hover:bg-[#353535] text-[#E0E0E0] rounded-xl transition-colors"
        >
          <ArrowRight size={18} />
        </Link>
        <div>
          <h1 className="text-xl font-bold text-[#D4AF37]">محادثة الدعم الفني</h1>
          <p className="text-xs text-[#9E9E9E] font-mono">{thread.id}</p>
        </div>
      </div>

      <SupportChat
        threadId={thread.id}
        initialMessages={messages}
        student={thread.profiles}
      />
    </div>
  );
}
