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

Deno.test('booking emails go to the place, with replies to support', async () => {
 for(const [k,v] of Object.entries({SUPABASE_URL:'https://backend.example.test',SUPABASE_SERVICE_ROLE_KEY:'test-key',NOTIFICATION_CRON_SECRET:'cron-secret',RESEND_API_KEY:'resend-test',NOTIFICATION_FROM:'test@example.test'})) Deno.env.set(k,v);
 const original=globalThis.fetch;
 const sent:any[]=[]; const acks:any[]=[];
 globalThis.fetch=async (input, init) => {
  const url=String(input);
  if(url.includes('notifications_pending_email_v2')) return Response.json([]);
  if(url.includes('venue_emails_pending')) return Response.json([{id:'v1',to_email:'boules@venue.test',subject:'Reservering voor 6 personen',body:'Beste team,\n\nGraag reserveren we.\n\nMet vriendelijke groet,\nOlivia'}]);
  if(url.includes('api.resend.com')) { sent.push(JSON.parse(String(init?.body))); return Response.json({id:'x'}); }
  if(url.includes('ack_venue_email')) { acks.push(JSON.parse(String(init?.body))); return new Response(null,{status:204}); }
  throw new Error(`Unexpected request: ${url}`);
 };
 try {
  const result=await handler(new Request('https://worker.example.test',{method:'POST',headers:{'x-cron-secret':'cron-secret'}}));
  assert(result.status===200,'worker ran');
  assert((await result.json()).booking_emails_sent===1,'one booking email sent');
  assert(sent.length===1 && sent[0].to[0]==='boules@venue.test','sent to the place');
  assert(sent[0].reply_to==='support@vriendtime.com','replies reach support');
  assert(sent[0].subject==='Reservering voor 6 personen' && sent[0].text.startsWith('Beste team,'),'subject and text as written');
  assert(sent[0].html.includes('<p>Met vriendelijke groet,<br>Olivia</p>'),'paragraphs and line breaks in the html');
  assert(acks.length===1 && acks[0].email_id==='v1' && acks[0].failure===null,'reported as sent');
 } finally { globalThis.fetch=original; }
});

Deno.test('week 5 emails in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('Week 5 is your call', 'nl'), 'Week 5 is jullie keuze');
  eq(translate('Week 5 of Thursday Circle is on Thu 05 Nov. Choose together what to do, where, and a start between 18:00 and 21:00. Talk it over in the chat, then save it in the app.', 'nl'),
     'Week 5 van Thursday Circle is op do 05 nov. Kies samen wat jullie doen, waar, en een begintijd tussen 18:00 en 21:00. Overleg in de chat en sla het op in de app.');
  eq(translate('Week 5 has no plan yet', 'nl'), 'Week 5 heeft nog geen plan');
  eq(translate('• Week 5 has no plan yet: Thursday Circle · week 5 on Thu 05 Nov: the group hasn’t planned it. Check the chat, or book something for them.', 'nl'),
     '• Week 5 heeft nog geen plan: Thursday Circle · week 5 op do 05 nov: de groep heeft nog niets gepland. Kijk in de chat, of boek iets voor ze.');
  eq(translate('Thursday Circle · week 5 on Thu 05 Nov: the group hasn’t planned it. Check the chat, or book something for them.', 'nl'),
     'Thursday Circle · week 5 op do 05 nov: de groep heeft nog niets gepland. Kijk in de chat, of boek iets voor ze.');
  eq(translate('Week 6 of Thursday Circle is planned as Graduation: a new beginning at Hofman. Want to do something else? Change it together in the app.', 'nl'),
     'Week 6 van Thursday Circle staat gepland als Afstuderen: een nieuw begin bij Hofman. Liever iets anders? Pas het samen aan in de app.');
});

Deno.test('booking alerts in Dutch, also in the digest', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('• A week to book: Thursday Circle · week 1 on Thu 22 Oct at The Boules Club: not booked yet.', 'nl'),
     '• Een week om te reserveren: Thursday Circle · week 1 op do 22 okt bij The Boules Club: nog niet gereserveerd.');
  eq(translate('A booking email failed', 'nl'), 'Een reserveringsmail is niet aangekomen');
  eq(translate('Thursday Circle · week 2: the booking email to The Boules Club could not be sent. Book it another way.', 'nl'),
     'Thursday Circle · week 2: de reserveringsmail aan The Boules Club kon niet worden verstuurd. Reserveer op een andere manier.');
});

Deno.test('pay-by reminders that fit the person, in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('Your invitation is waiting', 'nl'), 'Je uitnodiging wacht op je');
  eq(translate('Accept and pay for The Monday Circle by the end of tomorrow to keep your place.', 'nl'),
     'Accepteer en betaal voor The Monday Circle vóór morgen aan het eind van de dag om je plek te houden.');
  eq(translate('Reply to your invitation to The Monday Circle by the end of tomorrow to keep your place. Your fee is already paid.', 'nl'),
     'Reageer vóór morgen aan het eind van de dag op je uitnodiging voor The Monday Circle om je plek te houden. Je bijdrage is al betaald.');
  eq(translate('Last chance to say yes', 'nl'), 'Laatste kans om ja te zeggen');
  eq(translate('Saying yes to The Monday Circle closes at the end of tomorrow, so the places can be booked for the group.', 'nl'),
     'Ja zeggen tegen The Monday Circle kan tot morgen aan het eind van de dag, zodat de plekken voor de groep gereserveerd kunnen worden.');
  eq(translate('• A place is overdue: Anna has not said yes to The Monday Circle by the pay-by date. Send a reminder, or release the place to invite someone else.', 'nl'),
     '• Een plek is over tijd: Anna heeft vóór de betaaldatum geen ja gezegd tegen The Monday Circle. Stuur een herinnering, of geef de plek vrij om iemand anders uit te nodigen.');
});

Deno.test('week 5 news and evening one-to-ones in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('Week 5 is planned', 'nl'), 'Week 5 is gepland');
  eq(translate('Anna planned week 5: Pub quiz at Jonas Bistro Bar, starting 20:30.', 'nl'),
     'Anna heeft week 5 gepland: Pub quiz bij Jonas Bistro Bar, vanaf 20:30.');
  eq(translate('Anna changed week 5: Bowling at Bowling Alkmaar, starting 19:00.', 'nl'),
     'Anna heeft week 5 aangepast: Bowling bij Bowling Alkmaar, vanaf 19:00.');
  eq(translate('A drink with Sam tonight', 'nl'), 'Een drankje met Sam vanavond');
  eq(translate('No one-to-one for you this time. See you with the whole group!', 'nl'),
     'Deze keer geen één-op-ééntje voor jou. Tot ziens met de hele groep!');
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
  eq(translate('Week 1 of The Tuesday Circle is planned as Brunch together at Hofman. Want to do something else? Change it together in the app.', 'nl'),
     'Week 1 van The Tuesday Circle staat gepland als Samen brunchen bij Hofman. Liever iets anders? Pas het samen aan in de app.');
  eq(translate('Anna is busy, but Leo is free', 'nl'), 'Anna kan niet, maar Leo is vrij');
  eq(translate('Thu 22 Oct at 19:00 · Mr. Gold. Coffee or a drink, just the two of you. Can you make it? Answer in the app.', 'nl'),
     'do 22 okt om 19:00 · Mr. Gold. Koffie of een drankje, alleen jullie twee. Kun je? Antwoord in de app.');
  eq(translate('Wed 21 Oct at 19:00 · Mr. Gold. A drink in the evening, just as friends: whatever you like to drink. Can you make it? Answer in the app. Not for you? No reason needed.', 'nl'),
     'wo 21 okt om 19:00 · Mr. Gold. Een drankje in de avond, gewoon als vrienden: wat je maar wilt drinken. Kun je? Antwoord in de app. Liever niet? Uitleg is niet nodig.');
  eq(translate('You’re meeting Anna', 'nl'), 'Je spreekt af met Anna');
  eq(translate('Anna said yes to Sat 24 Oct at 14:00. If your plans changed, you can still say yes in the app.', 'nl'),
     'Anna zei ja tegen za 24 okt om 14:00. Als je plannen veranderd zijn, kun je in de app alsnog ja zeggen.');
  eq(translate('Enjoy your free week', 'nl'), 'Geniet van je vrije week');
  eq(translate('Your one-to-one on Tue 20 Oct at 10:30 is off. See you with the whole group!', 'nl'),
     'Je één-op-ééntje op di 20 okt om 10:30 gaat niet door. Tot ziens met de hele groep!');
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

Deno.test('pay-first emails in Dutch', async () => {
  const { translate } = await import('./copy.ts');
  const eq = (a: string, b: string) => assert(a === b, `${a} !== ${b}`);
  eq(translate('We’ve found people for your times', 'nl'), 'We hebben mensen gevonden voor jouw tijden');
  eq(translate('Your first meetup is on Thu 05 Nov at 20:00. Open the app to meet your group and see all six dates.', 'nl'),
    'Je eerste meetup is op do 05 nov om 20:00. Open de app om je groep te ontmoeten en alle zes de data te zien.');
  eq(translate('Thursday Circle filled up before your payment arrived, so your €39 holds your place in the next group for your times. We’ll invite you as soon as one fits.', 'nl'),
    'Thursday Circle was vol voordat je betaling binnenkwam, dus je €39 houdt je plek vast in de volgende groep voor jouw tijden. We nodigen je uit zodra er een past.');
  eq(translate('Anna didn’t pay for Thursday Circle within 7 days. Their seat is open: invite someone from the waiting list.', 'nl'),
    'Anna heeft niet binnen 7 dagen betaald voor Thursday Circle. De plek is vrij: nodig iemand van de wachtlijst uit.');
});
