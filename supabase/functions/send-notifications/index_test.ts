import { handler, render } from './index.ts';
function assert(value: unknown, message: string) { if (!value) throw new Error(message); }
const row = {id:'n1',lease_token:'lease1',email:'member@example.test',first_name:'<script>',kind:'update',title:'Hello',body:'A & B'};
Deno.test('email shows the logo from the website', () => {
 const result=render(row,'https://vriendtime.com');
 assert(result.html.includes('src="https://vriendtime.com/email/vriendtime-logo.png"'),'logo missing');
 assert(result.html.includes('alt="VriendTime"'),'logo needs alt text');
});
Deno.test('email escapes member text', () => {
 const result=render(row,'https://vriendtime.com/');
 assert(!result.html.includes('<script>'),'unsafe HTML');
 assert(result.html.includes('&lt;script&gt;'),'name should be escaped');
});
for (const failAck of [false,true]) Deno.test(`delivery uses stable idempotency and checks acknowledgement: ${failAck}`, async () => {
 for(const [k,v] of Object.entries({SUPABASE_URL:'https://backend.example.test',SUPABASE_SERVICE_ROLE_KEY:'test-key',NOTIFICATION_CRON_SECRET:'cron-secret',RESEND_API_KEY:'resend-test',NOTIFICATION_FROM:'test@example.test'})) Deno.env.set(k,v);
 const original=globalThis.fetch;
 let key='',acked=false;
 globalThis.fetch=async (input, init) => {
  const url=String(input);
  if(url.includes('notifications_pending_email_v2')) return Response.json([row]);
  if(url.includes('api.resend.com')) { key=new Headers(init?.headers).get('Idempotency-Key')??''; return Response.json({id:'provider-id'}); }
  if(url.includes('ack_notification_email')) { acked=true; return failAck?Response.json({message:'database unavailable'},{status:500}):new Response(null,{status:204}); }
  throw new Error(`Unexpected request: ${url}`);
 };
 try {
  const result=await handler(new Request('https://worker.example.test',{method:'POST',headers:{'x-cron-secret':'cron-secret'}}));
  assert(key==='vriendtime-notification/n1','missing stable dedupe key');
  assert(acked,'delivery not acknowledged');
  assert(result.status===(failAck?503:200),'ack error must fail invocation');
 } finally { globalThis.fetch=original; }
});
Deno.test('worker rejects unauthorised requests',async()=>{
 const response=await handler(new Request('https://worker.example.test',{method:'POST'}));
 assert(response.status===401,'unauthorised worker request accepted');
});
Deno.test('a provider limit hands the batch back without using attempts', async () => {
 for(const [k,v] of Object.entries({SUPABASE_URL:'https://backend.example.test',SUPABASE_SERVICE_ROLE_KEY:'test-key',NOTIFICATION_CRON_SECRET:'cron-secret',RESEND_API_KEY:'resend-test',NOTIFICATION_FROM:'test@example.test'})) Deno.env.set(k,v);
 const original=globalThis.fetch;
 const deferred:{id:string,seconds:number}[]=[]; let acked=false, sends=0;
 globalThis.fetch=async (input, init) => {
  const url=String(input);
  if(url.includes('notifications_pending_email_v2')) return Response.json([row,{...row,id:'n2',lease_token:'lease2'}]);
  if(url.includes('api.resend.com')) { sends++; return Response.json({name:'daily_quota_exceeded'},{status:429}); }
  if(url.includes('defer_notification_email')) { const b=JSON.parse(String(init?.body)); deferred.push({id:b.notification_id,seconds:b.retry_in_seconds}); return new Response(null,{status:204}); }
  if(url.includes('ack_notification_email')) { acked=true; return new Response(null,{status:204}); }
  throw new Error(`Unexpected request: ${url}`);
 };
 try {
  const result=await handler(new Request('https://worker.example.test',{method:'POST',headers:{'x-cron-secret':'cron-secret'}}));
  assert(result.status===200,'limit is not an error');
  assert(sends===1,'stops sending after the limit');
  assert(!acked,'a limited email is not counted as a failed attempt');
  assert(deferred.length===2 && deferred.every(d=>d.seconds===3600),'both emails wait an hour');
 } finally { globalThis.fetch=original; }
});

Deno.test('a Dutch member gets Dutch, with a link to the right screen', () => {
 const r=render({...row,first_name:'Noor',title:'How was your meetup?',body:'Pick how it felt and, if you like, who you’d enjoy seeing more of. It stays private: only you and the organiser see it.',language:'nl',open:'checkin:abc'},'https://vriendtime.com');
 assert(r.html.includes('Hoe was je meetup?'),'title in Dutch');
 assert(r.html.includes('Hoi Noor,'),'greeting in Dutch');
 assert(r.html.includes('href="https://vriendtime.com/?open=checkin%3Aabc&amp;lang=nl"'),'deep link');
 assert(r.html.includes('Laat weten hoe het was'),'button label');
 assert(r.text.includes('?open=checkin%3Aabc&lang=nl'),'plain text has the link');
});
Deno.test('names inside sentences survive translation', () => {
 const r=render({...row,title:'New messages in your Circle',body:'3 new messages in The Thursday Circle. Open VriendTime to read and reply.',language:'nl',open:'messages'},'https://vriendtime.com');
 assert(r.html.includes('3 nieuwe berichten in The Thursday Circle.'),'pattern translation');
});
Deno.test('English stays English and home has no query', () => {
 const r=render({...row,title:'You’re invited to a Circle',body:'x',language:'en',open:'home'},'https://vriendtime.com');
 assert(r.html.includes('href="https://vriendtime.com/"'),'plain home link');
 assert(r.html.includes('Open VriendTime'),'default label');
});

Deno.test('the programme reminders read naturally in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const assertEquals = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  assertEquals(translate('Your plan for week 5', 'nl'), 'Jullie plan voor week 5');
  assertEquals(
    translate('Week 5 of The Tuesday Circle is planned as Coffee at De Koffiemolen. Want to do something else? Change it together in the app.', 'nl'),
    'Week 5 van The Tuesday Circle staat gepland als Koffie bij De Koffiemolen. Liever iets anders? Pas het samen aan in de app.');
  assertEquals(
    translate('Week 6 of The Tuesday Circle is planned as Drinks. Want to do something else? Change it together in the app.', 'nl'),
    'Week 6 van The Tuesday Circle staat gepland als Borrelen. Liever iets anders? Pas het samen aan in de app.');
  assertEquals(
    translate('Circle A · week 2 on Tue 20 Oct: add the place so members know where to go.', 'nl'),
    'Circle A · week 2 op di 20 okt: voeg de plek toe zodat leden weten waar ze heen moeten.');
});

Deno.test('one-to-one coffees in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('This week you could meet Anna', 'nl'), 'Deze week kun je Anna ontmoeten');
  eq(translate('Anna is busy, but Leo is free', 'nl'), 'Anna kan niet, maar Leo is vrij');
  eq(translate('Thu 22 Oct at 19:00 · Mr. Gold. Coffee or a drink, just the two of you. Can you make it? Answer in the app.', 'nl'),
     'do 22 okt om 19:00 · Mr. Gold. Koffie of een drankje, alleen jullie twee. Kun je? Antwoord in de app.');
  eq(translate('You’re meeting Anna', 'nl'), 'Je spreekt af met Anna');
  eq(translate('Anna said yes to Sat 24 Oct at 14:00. If your plans changed, you can still say yes in the app.', 'nl'),
     'Anna zei ja tegen za 24 okt om 14:00. Als je plannen veranderd zijn, kun je in de app alsnog ja zeggen.');
  eq(translate('Enjoy your free week', 'nl'), 'Geniet van je vrije week');
  eq(translate('Your coffee on Tue 20 Oct at 10:30 is off. See you with the whole group!', 'nl'),
     'Je koffie op di 20 okt om 10:30 gaat niet door. Tot ziens met de hele groep!');
});

Deno.test('the organiser digest: one line per item, in Dutch too', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('• 2 payments to confirm\n• A meetup has no place yet: Circle A · week 3 on Thu 22 Oct: add the place so members know where to go.', 'nl'),
     '• 2 betalingen om te bevestigen\n• Een meetup heeft nog geen plek: Circle A · week 3 op do 22 okt: voeg de plek toe zodat leden weten waar ze heen moeten.');
  eq(translate('Things to do in VriendTime', 'nl'), 'Te doen in VriendTime');
  const { html } = render({ ...row, title: 'Things to do in VriendTime', body: '• 1 open report\n• 1 payment to confirm', language: 'en', open: 'organiser:todo' } as never, 'https://vriendtime.com');
  assert(html.includes('• 1 open report<br>• 1 payment to confirm'), 'lines become line breaks');
});

Deno.test('the coffee reminder in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('Coffee with Anna today', 'nl'), 'Koffie met Anna vandaag');
  eq(translate('19:00 at Mr. Gold. Running late? Say so in the group chat.', 'nl'), '19:00 bij Mr. Gold. Ben je later? Laat het weten in de groepschat.');
});

Deno.test('running late in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('Anna is running late', 'nl'), 'Anna is later');
  eq(translate('About 10 minutes. Your coffee at 19:00 at Mr. Gold.', 'nl'), 'Ongeveer 10 minuten. Jullie koffie om 19:00 bij Mr. Gold.');
  eq(translate('19:00 at Mr. Gold. Running late? Let them know in the app.', 'nl'), '19:00 bij Mr. Gold. Ben je later? Laat het weten in de app.');
  eq(translate('Thu 22 Oct at 19:00 · Mr. Gold. Running late? Let them know in the app.', 'nl'), 'do 22 okt om 19:00 · Mr. Gold. Ben je later? Laat het weten in de app.');
});
