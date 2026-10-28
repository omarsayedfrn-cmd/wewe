'use client';

import { useState, useEffect, useRef } from 'react';
import { Send, User, Shield } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

export function SupportChat({
  threadId,
  initialMessages,
  student,
}: {
  threadId: string;
  initialMessages: any[];
  student: any;
}) {
  const [messages, setMessages] = useState<any[]>(initialMessages);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Realtime subscription
  useEffect(() => {
    const supabase = createClient();
    const channel = supabase
      .channel(`support_thread_${threadId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `thread_id=eq.${threadId}`,
        },
        (payload) => {
          setMessages((prev) => {
            if (prev.some((m) => m.id === payload.new.id)) return prev;
            return [...prev, payload.new];
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [threadId]);

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    if (!input.trim() || sending) return;

    const body = input.trim();
    const tempId = `temp-${Date.now()}`;

    // Show the bubble immediately instead of waiting for a server refresh.
    setMessages((prev) => [
      ...prev,
      {
        id: tempId,
        thread_id: threadId,
        sender_role: 'admin',
        body,
        created_at: new Date().toISOString(),
      },
    ]);
    setInput('');
    setSending(true);

    try {
      const res = await fetch('/api/admin/support/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ threadId, body }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'فشل إرسال الرسالة');

      const sent = data.message;
      setMessages((prev) => {
        const withoutTemp = prev.filter((m) => m.id !== tempId);
        if (!sent) return withoutTemp;
        return withoutTemp.some((m) => m.id === sent.id)
          ? withoutTemp
          : [...withoutTemp, sent];
      });
    } catch (err: any) {
      setMessages((prev) => prev.filter((m) => m.id !== tempId));
      setInput(body);
      alert(err.message);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="flex h-[calc(100dvh-9rem)] min-h-[24rem] flex-col overflow-hidden rounded-2xl border border-[#2A2A2A] bg-[#1E1E1E] shadow-xl sm:h-[75vh]">
      {/* Thread Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[#333] bg-[#252525] p-4">
        <div className="flex min-w-0 items-center gap-3">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#800020] font-bold text-white">
            {(student?.display_name || 'U')[0].toUpperCase()}
          </div>
          <div className="min-w-0">
            <h2 className="truncate font-bold text-[#E0E0E0]">
              {student?.display_name || 'مستخدم'}
            </h2>
            <p className="truncate text-xs text-[#9E9E9E]">
              كود الإحالة:{' '}
              <span className="font-mono text-[#D4AF37]">
                {student?.referral_code}
              </span>
            </p>
          </div>
        </div>

        <a
          href={`/users/${student?.id}`}
          className="rounded-lg bg-[#800020]/20 px-3 py-1.5 text-xs text-[#D4AF37] transition-colors hover:bg-[#800020]/40"
        >
          عرض ملف الطالب
        </a>
      </div>

      {/* Messages Scroll Area */}
      <div className="flex-1 space-y-4 overflow-y-auto p-4 sm:p-6">
        {messages.length === 0 ? (
          <div className="flex h-full items-center justify-center text-sm text-[#9E9E9E]">
            لا توجد رسائل سابقة في هذه المحادثة
          </div>
        ) : (
          messages.map((m) => {
            const isAdmin = m.sender_role === 'admin';
            return (
              <div
                key={m.id}
                className={`flex flex-col ${isAdmin ? 'items-start' : 'items-end'}`}
              >
                <div className="mb-1 flex items-center gap-1.5 px-1 text-xs text-[#9E9E9E]">
                  {isAdmin ? (
                    <>
                      <Shield size={12} className="text-[#D4AF37]" />
                      <span>الإدارة (أنت)</span>
                    </>
                  ) : (
                    <>
                      <User size={12} />
                      <span>{student?.display_name || 'الطالب'}</span>
                    </>
                  )}
                  <span>•</span>
                  <span>
                    {new Date(m.created_at).toLocaleTimeString('ar-EG', {
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>

                <div
                  className={`max-w-[85%] whitespace-pre-wrap rounded-2xl p-3.5 text-sm leading-relaxed sm:max-w-[75%] ${
                    isAdmin
                      ? 'rounded-tr-none bg-[#800020] text-white shadow-md'
                      : 'rounded-tl-none border border-[#3A3A3A] bg-[#2A2A2A] text-[#E0E0E0]'
                  }`}
                >
                  {m.body}
                </div>
              </div>
            );
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input Bar */}
      <form
        onSubmit={handleSend}
        className="flex gap-2 border-t border-[#333] bg-[#252525] p-3 sm:gap-3 sm:p-4"
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="اكتب ردك هنا..."
          className="min-w-0 flex-1 rounded-xl border border-[#3A3A3A] bg-[#1E1E1E] px-4 py-3 text-sm text-[#E0E0E0] outline-none focus:border-[#D4AF37]"
        />
        <button
          type="submit"
          disabled={sending || !input.trim()}
          className="flex touch-manipulation items-center gap-2 rounded-xl bg-[#800020] px-4 py-3 text-sm font-semibold text-white transition-colors hover:bg-[#A0334A] active:scale-95 disabled:opacity-50 sm:px-5"
        >
          <Send size={16} />
          <span className="hidden sm:inline">
            {sending ? 'إرسال...' : 'إرسال'}
          </span>
        </button>
      </form>
    </div>
  );
}