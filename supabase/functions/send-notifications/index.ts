// Delivers queued notifications by email.
//
// Everything the app promises to tell someone — your Circle is ready, here is
// the venue, see you tomorrow — is a row in public.notifications. Without this
// function those rows are only visible to people who happen to open the app,
// which for a weekly programme means people miss meetups.
//
// A database schedule calls it every 10 minutes while something is waiting
// (migration 20261012). It claims a batch, sends each one, and records the
// outcome so a failure is retried and a permanently bad address is retired
// after five attempts. When the email provider says "not now" (its daily cap),
// the rest of the batch is handed back without using up an attempt.
//
// Required secrets:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (set automatically by Supabase)
//   RESEND_API_KEY                           (from resend.com)
//   NOTIFICATION_FROM   e.g. "VriendTime <hello@vriendtime.com>"
//   NOTIFICATION_REPLY_TO  optional, defaults to support@vriendtime.com
//   NOTIFICATION_CRON_SECRET                 (any long random string)
//   APP_URL             e.g. "https://vriendtime.com"  (link back into the app)
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const BATCH_SIZE = 50;
// The email provider accepts a few requests per second; stay under it.
const PAUSE_MS = 600;

type Pending = {
  id: string;
  lease_token: string;
  email: string;
  first_name: string | null;
  kind: string;
  title: string;
  body: string;
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/// The logo is served by the website itself (web/email/ in the app).
export function logoUrl(appUrl: string): string {
  return new URL("/email/vriendtime-logo.png", appUrl).toString();
}

/// The email says what happened and sends people to the app; it never repeats
/// details like a venue or another member's name, so a forwarded or
/// mis-delivered message gives nothing away.
export function render(row: Pending, appUrl: string): { html: string; text: string } {
  const greeting = row.first_name ? `Hi ${row.first_name},` : "Hi,";
  const title = escapeHtml(row.title);
  const body = escapeHtml(row.body);
  const text =
    `${greeting}\n\n${row.title}\n\n${row.body}\n\nOpen VriendTime: ${appUrl}\n\n` +
    `You can turn these emails off under Profile in the app.`;
  const html = `<!doctype html>
<html lang="en"><body style="margin:0;background:#FBF8F3;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#12314B">
  <div style="max-width:520px;margin:0 auto;padding:32px 24px">
    <div style="margin-bottom:28px">
      <img src="${escapeHtml(logoUrl(appUrl))}" width="200" height="45" alt="VriendTime" style="display:block;border:0;width:200px;height:45px;font-size:22px;font-weight:700;color:#145247">
    </div>
    <div style="background:#fff;border-radius:20px;padding:28px 24px">
      <p style="margin:0 0 18px;font-size:15px;color:#4A6076">${escapeHtml(greeting)}</p>
      <h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;font-weight:700">${title}</h1>
      <p style="margin:0 0 24px;font-size:15px;line-height:1.55;color:#33506B">${body}</p>
      <a href="${escapeHtml(appUrl)}" style="display:inline-block;background:#145247;color:#fff;text-decoration:none;padding:13px 22px;border-radius:999px;font-weight:700;font-size:15px">Open VriendTime</a>
    </div>
    <p style="margin:22px 4px 0;font-size:12px;line-height:1.5;color:#7A8B99">
      You are receiving this because you applied for a Friendship Circle in Alkmaar.
      You can turn these emails off under Profile in the app.
    </p>
  </div>
</body></html>`;
  return { html, text };
}

export async function handler(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return new Response("Method not allowed.", { status: 405 });
  }

  // The schedule is the only caller. A shared secret keeps the endpoint from
  // being used to drain the queue or probe who has mail waiting.
  const expected = Deno.env.get("NOTIFICATION_CRON_SECRET");
  if (!expected || request.headers.get("x-cron-secret") !== expected) {
    return new Response("Not authorised.", { status: 401 });
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("NOTIFICATION_FROM");
  // Replies to an app email reach a mailbox someone reads.
  const replyTo = Deno.env.get("NOTIFICATION_REPLY_TO") ?? "support@vriendtime.com";
  if (!resendKey || !from) {
    return new Response("Email is not configured.", { status: 500 });
  }
  const appUrl = Deno.env.get("APP_URL") ?? "https://vriendtime.com";

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase.rpc("notifications_pending_email", {
    max_rows: BATCH_SIZE,
  });
  if (error) {
    return new Response(`Could not read the queue: ${error.message}`, {
      status: 500,
    });
  }

  const pending = (data ?? []) as Pending[];
  let sent = 0;
  const started = Date.now();

  // Hand rows back unsent, without using up an attempt.
  const deferRest = async (rows: Pending[], seconds: number, reason: string | null) => {
    for (const row of rows) {
      const result = await supabase.rpc("defer_notification_email", {
        notification_id: row.id, lease_token: row.lease_token,
        retry_in_seconds: seconds, reason,
      });
      // The lease then simply expires and the row is picked up again later.
      if (result.error) console.error("Could not defer email", row.id);
    }
  };

  for (let i = 0; i < pending.length; i++) {
    const row = pending[i];
    // Finish well before the five-minute lease; the rest waits for next time.
    if (Date.now() - started > 90_000) {
      await deferRest(pending.slice(i), 0, null);
      break;
    }
    if (i > 0) await new Promise((resolve) => setTimeout(resolve, PAUSE_MS));
    const { html, text } = render(row, appUrl);
    let failure: string | null = null;
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST", signal: AbortSignal.timeout(10_000),
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json",
          "Idempotency-Key": `vriendtime-notification/${row.id}` },
        body: JSON.stringify({ from, to: [row.email], reply_to: replyTo, subject: row.title, html, text }),
      });
      if (response.status === 429) {
        // Daily or monthly cap: try again in an hour. Too many requests at
        // once: in two minutes. Nothing was sent, so no attempt is used.
        const detail = await response.text().catch(() => "");
        const seconds = /quota/i.test(detail) ? 3600 : 120;
        await deferRest(pending.slice(i), seconds, "Email provider limit reached; retrying later.");
        break;
      }
      if (!response.ok) failure = `Provider HTTP ${response.status}`;
    } catch { failure = "Delivery interrupted; retry with the same idempotency key."; }
    const ack = await supabase.rpc("ack_notification_email", {
      notification_id: row.id, lease_token: row.lease_token, failure,
    });
    if (ack.error) {
      console.error("Email acknowledgement failed", row.id);
      return new Response("Could not record delivery. Safe retry required.", { status: 503 });
    }
    if (failure === null) sent++;
  }

  return new Response(
    JSON.stringify({
      considered: pending.length,
      sent,
      not_sent: pending.length - sent,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
}

if (import.meta.main) Deno.serve(handler);
