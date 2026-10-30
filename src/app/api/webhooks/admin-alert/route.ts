import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { createAdminClient } from '@/lib/supabase/server';

// Runs on Node so we can sign the FCM JWT with the built-in crypto module.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type WebhookBody = {
  table?: string;
  op?: string;
  record?: Record<string, unknown>;
};

function base64url(input: Buffer | string) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function getFcmAccessToken(sa: {
  client_email: string;
  private_key: string;
  token_uri: string;
}) {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: sa.token_uri,
      iat: now,
      exp: now + 3600,
    })
  )}`;

  const signature = crypto.sign('RSA-SHA256', Buffer.from(unsigned), sa.private_key);
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`FCM token exchange failed: ${await res.text()}`);
  const json = await res.json();
  return json.access_token as string;
}

function buildMessage(body: WebhookBody) {
  const r = (body.record ?? {}) as Record<string, unknown>;
  switch (body.table) {
    case 'profiles':
      return {
        title: 'حساب جديد محتاج تفعيل',
        body: (r.display_name as string) || 'طالب جديد بانتظار التفعيل',
        href: `/users/${r.id}`,
      };
    case 'support_messages':
      return {
        title: 'رسالة دعم محتاجة رد',
        body: ((r.body as string) || 'رسالة جديدة').slice(0, 120),
        href: `/support/${r.thread_id}`,
      };
    case 'support_threads':
      return {
        title: 'تذكرة دعم جديدة',
        body: 'محادثة دعم جديدة بانتظار الرد',
        href: `/support/${r.id}`,
      };
    case 'audit_logs':
      return {
        title: 'تغيير جديد في النظام',
        body: (r.action as string) || 'تم تسجيل نشاط جديد',
        href: '/audit',
      };
    default:
      return null;
  }
}

export async function POST(req: NextRequest) {
  try {
    const secret = process.env.ADMIN_WEBHOOK_SECRET;
    if (!secret || req.headers.get('x-webhook-secret') !== secret) {
      return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
    }

    const body = (await req.json()) as WebhookBody;
    const message = buildMessage(body);
    if (!message) return NextResponse.json({ skipped: true });

    const saRaw = process.env.FCM_SERVICE_ACCOUNT;
    if (!saRaw) throw new Error('FCM_SERVICE_ACCOUNT not configured');
    const sa = JSON.parse(saRaw);
    const projectId = sa.project_id as string;

    const supabase = await createAdminClient();
    const [tokensRes, accessToken] = await Promise.all([
      supabase.from('admin_devices').select('token'),
      getFcmAccessToken(sa),
    ]);

    const tokens = (tokensRes.data ?? []).map((r) => r.token as string);
    if (tokens.length === 0) return NextResponse.json({ delivered: 0 });

    const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    let delivered = 0;

    await Promise.all(
      tokens.map(async (token) => {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: message.title, body: message.body },
              data: { href: message.href },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'admin-alerts',
                  color: '#800020',
                  sound: 'default',
                },
              },
            },
          }),
        });
        if (res.ok) delivered++;
      })
    );

    return NextResponse.json({ delivered, total: tokens.length });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
