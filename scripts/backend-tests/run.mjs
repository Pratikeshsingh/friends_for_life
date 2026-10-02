import { PGlite } from '@electric-sql/pglite';
import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const db=new PGlite();
async function run(file) {
 let sql=await readFile(path.join(root,file),'utf8');
 // PGlite has core gen_random_uuid; the schema uses no other pgcrypto API.
 sql=sql.replace('create extension if not exists pgcrypto;', '');
 try { await db.exec(sql); console.log('PASS '+file); }
 catch(e) { console.error('FAIL '+file+'\n'+e.message+'\n'+(e.where??'')+'\n'+(e.detail??'')); process.exitCode=1; throw e; }
}
try {
 await run('scripts/backend-tests/bootstrap.sql');
 await run('supabase/schema.sql');
 await run('supabase/release_hardening.sql');
 for(const file of (await readdir(path.join(root,'supabase/migrations'))).sort()) await run('supabase/migrations/'+file);
 const tests=process.argv.slice(2);
 for(const file of tests.length?tests:['production_hardening_test.sql']) await run('supabase/tests/'+file);
} catch { process.exitCode=1; } finally { await db.close(); }
