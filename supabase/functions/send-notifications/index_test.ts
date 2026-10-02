import { handler, render } from './index.ts';
function assert(value: unknown, message: string) { if (!value) throw new Error(message); }
const row = {id:'n1',lease_token:'lease1',email:'member@example.test',first_name:'<script>',kind:'update',title:'Hello',body:'A & B'};
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
  if(url.includes('notifications_pending_email')) return Response.json([row]);
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
