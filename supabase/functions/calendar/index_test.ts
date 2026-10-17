import { buildIcs, handler } from './index.ts';
function assert(value: unknown, message: string) { if (!value) throw new Error(message); }
const event = { uid: 'e1', title: 'VriendTime · Dinner, together', start: '2026-10-22T17:00:00Z', end: '2026-10-22T19:00:00Z', location: 'Rozey Alkmaar, Alkmaar', link: 'https://vriendtime.com/?open=meetup:e1' };

Deno.test('a valid calendar invitation', () => {
  const ics = buildIcs(event, new Date('2026-10-13T10:00:00Z'));
  assert(ics.includes('DTSTART:20261022T170000Z'), 'start in UTC');
  assert(ics.includes('DTEND:20261022T190000Z'), 'end in UTC');
  assert(ics.includes('SUMMARY:VriendTime · Dinner\\, together'), 'commas escaped');
  assert(ics.includes('\r\n'), 'CRLF line endings');
});

Deno.test('serves text/calendar for a known id', async () => {
  const id = '11111111-2222-3333-4444-555555555555';
  const res = await handler(new Request(`https://x/functions/v1/calendar?meetup=${id}`), async (k, i) => k === 'meetup' && i === id ? event : null);
  assert(res.status === 200, 'ok');
  assert((res.headers.get('content-type') ?? '').startsWith('text/calendar'), 'calendar type');
});

Deno.test('unknown or malformed ids get nothing', async () => {
  const none = async () => null;
  assert((await handler(new Request('https://x/calendar?meetup=abc'), none)).status === 404, 'malformed');
  assert((await handler(new Request('https://x/calendar?coffee=11111111-2222-3333-4444-555555555555'), none)).status === 404, 'unknown');
  assert((await handler(new Request('https://x/calendar'), none)).status === 404, 'no id');
});

Deno.test("a one-to-one is a coffee by day and a drink in the evening", async () => {
  const { oneToOneKind } = await import("./index.ts");
  if (oneToOneKind("2026-10-22T12:00:00Z") !== "Coffee") throw new Error("14:00 is a coffee");
  if (oneToOneKind("2026-10-22T18:00:00Z") !== "A drink") throw new Error("20:00 is a drink");
  if (oneToOneKind("2026-11-05T19:00:00Z") !== "A drink") throw new Error("20:00 in winter is a drink");
});
