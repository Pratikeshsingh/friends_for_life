// Delivers queued notifications by email.
//
// Everything the app promises to tell someone — your Circle is ready, here is
// the venue, see you tomorrow — is a row in public.notifications. Without this
// function those rows are only visible to people who happen to open the app,
// which for a weekly programme means people miss meetups.
//
// Run it on a schedule (every 15 minutes is plenty). It claims a batch, sends
// each one, and records the outcome so a failure is retried and a permanently
// bad address is retired after three attempts.
//
// Required secrets:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (set automatically by Supabase)
//   RESEND_API_KEY                           (from resend.com)
//   NOTIFICATION_FROM   e.g. "VriendTime <hallo@vriendtime.nl>"
//   NOTIFICATION_CRON_SECRET                 (any long random string)
//   APP_URL             e.g. "https://vriendtime.nl"  (link back into the app)
import { createClient } from "npm:@supabase/supabase-js@2";

const BATCH_SIZE = 50;

type Pending = {
  id: string;
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

/// The email says what happened and sends people to the app; it never repeats
/// details like a venue or another member's name, so a forwarded or
/// mis-delivered message gives nothing away.
function render(row: Pending, appUrl: string): { html: string; text: string } {
  const greeting = row.first_name ? `Hi ${row.first_name},` : "Hi,";
  const title = escapeHtml(row.title);
  const body = escapeHtml(row.body);
  const text =
    `${greeting}\n\n${row.title}\n\n${row.body}\n\nOpen VriendTime: ${appUrl}\n\n` +
    `You can turn these emails off under Profile in the app.`;
  const html = `<!doctype html>
<html lang="en"><body style="margin:0;background:#FBF8F3;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#12314B">
  <div style="max-width:520px;margin:0 auto;padding:32px 24px">
    <div style="font-size:20px;font-weight:700;letter-spacing:-.2px;margin-bottom:28px">
      <span style="color:#12314B">Vriend</span><span style="color:#F2765B">Time</span>
    </div>
    <div style="background:#fff;border-radius:20px;padding:28px 24px">
      <p style="margin:0 0 18px;font-size:15px;color:#4A6076">${escapeHtml(greeting)}</p>
      <h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;font-weight:700">${title}</h1>
      <p style="margin:0 0 24px;font-size:15px;line-height:1.55;color:#33506B">${body}</p>
      <a href="${escapeHtml(appUrl)}" style="display:inline-block;background:#14776A;color:#fff;text-decoration:none;padding:13px 22px;border-radius:999px;font-weight:700;font-size:15px">Open VriendTime</a>
    </div>
    <p style="margin:22px 4px 0;font-size:12px;line-height:1.5;color:#7A8B99">
      You are receiving this because you applied for a Friendship Circle in Alkmaar.
      You can turn these emails off under Profile in the app.
    </p>
  </div>
</body></html>`;
  return { html, text };
}

Deno.serve(async (request: Request) => {
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
  if (!resendKey || !from) {
    return new Response("Email is not configured.", { status: 500 });
  }
  const appUrl = Deno.env.get("APP_URL") ?? "https://vriendtime.nl";

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
  const sent: string[] = [];
  const failures = new Map<string, string[]>();

  for (const row of pending) {
    const { html, text } = render(row, appUrl);
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: [row.email],
          subject: row.title,
          html,
          text,
        }),
      });
      if (response.ok) {
        sent.push(row.id);
      } else {
        // Group by reason so one update call covers every row that failed the
        // same way, and the reason is readable in the table afterwards.
        const reason = `${response.status}: ${(await response.text()).slice(0, 300)}`;
        failures.set(reason, [...(failures.get(reason) ?? []), row.id]);
      }
    } catch (cause) {
      const reason = `network: ${String(cause).slice(0, 300)}`;
      failures.set(reason, [...(failures.get(reason) ?? []), row.id]);
    }
  }

  // Recording the outcome matters more than the send: an unrecorded success
  // is sent again on the next run, which is how people get duplicates.
  if (sent.length > 0) {
    await supabase.rpc("mark_notifications_emailed", { ids: sent });
  }
  for (const [reason, ids] of failures) {
    await supabase.rpc("mark_notifications_emailed", { ids, failure: reason });
  }

  return new Response(
    JSON.stringify({
      considered: pending.length,
      sent: sent.length,
      failed: pending.length - sent.length,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
