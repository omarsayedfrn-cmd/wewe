'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
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
  const router = useRouter();
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
    setInput('');
    setSending(true);

    try {
      const res = await fetch('/api/admin/support/reply', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ threadId, body }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || 'فشل إرسال الرسالة');
      }

      router.refresh();
    } catch (err: any) {
      alert(err.message);
      setInput(body);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="bg-[#1E1E1E] border border-[#2A2A2A] rounded-2xl flex flex-col h-[75vh] shadow-xl overflow-hidden">
      {/* Thread Header */}
      <div className="p-4 bg-[#252525] border-b border-[#333] flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-[#800020] rounded-xl flex items-center justify-center text-white font-bold">
            {(student?.display_name || 'U')[0].toUpperCase()}
          </div>
          <div>
            <h2 className="font-bold text-[#E0E0E0]">{student?.display_name || 'مستخدم'}</h2>
            <p className="text-xs text-[#9E9E9E]">
              كود الإحالة: <span className="font-mono text-[#D4AF37]">{student?.referral_code}</span>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <a
            href={`/users/${student?.id}`}
            className="text-xs px-3 py-1.5 bg-[#800020]/20 hover:bg-[#800020]/40 text-[#D4AF37] rounded-lg transition-colors"
          >
            عرض ملف الطالب
          </a>
        </div>
      </div>

      {/* Messages Scroll Area */}
      <div className="flex-1 p-6 overflow-y-auto space-y-4">
        {messages.length === 0 ? (
          <div className="h-full flex items-center justify-center text-[#9E9E9E] text-sm">
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
                <div className="flex items-center gap-1.5 mb-1 px-1 text-xs text-[#9E9E9E]">
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
                  <span>{new Date(m.created_at).toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' })}</span>
                </div>

                <div
                  className={`max-w-[75%] p-3.5 rounded-2xl text-sm leading-relaxed whitespace-pre-wrap ${
                    isAdmin
                      ? 'bg-[#800020] text-white rounded-tr-none shadow-md'
                      : 'bg-[#2A2A2A] text-[#E0E0E0] rounded-tl-none border border-[#3A3A3A]'
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
      <form onSubmit={handleSend} className="p-4 bg-[#252525] border-t border-[#333] flex gap-3">
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="اكتب ردك هنا..."
          className="flex-1 px-4 py-3 bg-[#1E1E1E] border border-[#3A3A3A] rounded-xl text-[#E0E0E0] focus:border-[#D4AF37] outline-none text-sm"
        />
        <button
          type="submit"
          disabled={sending || !input.trim()}
          className="px-5 py-3 bg-[#800020] hover:bg-[#A0334A] text-white rounded-xl transition-colors font-semibold flex items-center gap-2 text-sm disabled:opacity-50"
        >
          <Send size={16} />
          {sending ? 'إرسال...' : 'إرسال'}
        </button>
      </form>
    </div>
  );
}
