// A calendar invitation for one meetup or one-to-one coffee, served as
// text/calendar so iPhone and Mac Safari offer "Add to Calendar" directly.
//
//   GET /functions/v1/calendar?meetup=<event id>
//   GET /functions/v1/calendar?coffee=<coffee id>
//
// Deployed without JWT verification: Apple Calendar cannot sign in. It only
// answers for an unguessable id and only with what an invitee already sees
// (title, time, place). Nothing else is read or returned.
import { createClient } from "npm:@supabase/supabase-js@2.117.2";

export type CalendarEvent = {
  uid: string;
  title: string;
  start: string;
  end: string;
  location: string;
  link: string;
};

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function stamp(iso: string): string {
  return new Date(iso).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

function esc(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/;/g, "\;").replace(/,/g, "\\,").replace(/\n/g, "\\n");
}

export function buildIcs(e: CalendarEvent, now = new Date()): string {
  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//VriendTime//Circles//EN",
    "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:${e.uid}@vriendtime.com`,
    `DTSTAMP:${stamp(now.toISOString())}`,
    `DTSTART:${stamp(e.start)}`,
    `DTEND:${stamp(e.end)}`,
    `SUMMARY:${esc(e.title)}`,
    `LOCATION:${esc(e.location)}`,
    `DESCRIPTION:${esc(`Open VriendTime for the latest plan: ${e.link}`)}`,
    `URL:${e.link}`,
    "END:VEVENT",
    "END:VCALENDAR",
    "",
  ].join("\r\n");
}

/** A coffee by day, a drink in the evening (from 17:00 Netherlands time). */
export function oneToOneKind(startsAt: string): string {
  const hour = Number(new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Amsterdam", hour: "2-digit", hourCycle: "h23",
  }).format(new Date(startsAt)));
  return hour >= 17 ? "A drink" : "Coffee";
}

export type Lookup = (kind: "meetup" | "coffee", id: string) => Promise<CalendarEvent | null>;

export async function handler(req: Request, lookup: Lookup): Promise<Response> {
  const url = new URL(req.url);
  const kind = url.searchParams.has("meetup") ? "meetup" : url.searchParams.has("coffee") ? "coffee" : null;
  const id = kind ? url.searchParams.get(kind) ?? "" : "";
  if (req.method !== "GET" || !kind || !uuid.test(id)) {
    return new Response("Not found", { status: 404 });
  }
  const event = await lookup(kind, id);
  if (!event) return new Response("Not found", { status: 404 });
  return new Response(buildIcs(event), {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="vriendtime.ics"',
      "Cache-Control": "no-store",
    },
  });
}

function supabaseLookup(): Lookup {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  return async (kind, id) => {
    if (kind === "meetup") {
      const { data } = await db.from("events")
        .select("id,title,starts_at,ends_at,venue_name,venue_address,status,circle_id")
        .eq("id", id).not("circle_id", "is", null).neq("status", "cancelled").maybeSingle();
      if (!data) return null;
      const place = [data.venue_name, data.venue_address].filter((v) => v && `${v}`.trim()).join(", ");
      return {
        uid: data.id,
        title: `VriendTime · ${data.title}`,
        start: data.starts_at,
        end: data.ends_at,
        location: place ? `${place}, Alkmaar` : "Alkmaar",
        link: `https://vriendtime.com/?open=meetup:${data.id}`,
      };
    }
    const { data } = await db.from("circle_coffees")
      .select("id,starts_at,place,address,status,a,b").eq("id", id).neq("status", "off").maybeSingle();
    if (!data) return null;
    const { data: people } = await db.from("profiles").select("id,first_name").in("id", [data.a, data.b]);
    const names = (people ?? []).map((p) => p.first_name).filter(Boolean).join(" & ");
    const end = new Date(new Date(data.starts_at).getTime() + 60 * 60 * 1000).toISOString();
    return {
      uid: data.id,
      title: `VriendTime · ${oneToOneKind(data.starts_at)}${names ? ` (${names})` : ""}`,
      start: data.starts_at,
      end,
      location: [data.place, data.address].filter((v) => v && `${v}`.trim()).join(", ") + ", Alkmaar",
      link: "https://vriendtime.com/?open=home",
    };
  };
}

if (import.meta.main) {
  const lookup = supabaseLookup();
  Deno.serve((req) => handler(req, lookup));
}
