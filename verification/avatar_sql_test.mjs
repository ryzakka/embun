// Run with Node and @electric-sql/pglite@0.5.17 installed beside this script.
// Usage: node profile_sql_test.mjs /absolute/path/to/migration.sql
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
let checks = 0;
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const user = n => id(n);
const room = n => id(100+n);
const query = async (sql, params=[]) => (await db.query(sql,params)).rows;
const equal = (actual, expected) => { assert.deepEqual(actual,expected); checks++; };
async function reject(action, code='42501') {
  await assert.rejects(action, e => e.code === code); checks++;
}
async function asUser(n, action) {
  await db.exec('set role authenticated');
  await query("select set_config('request.jwt.claim.sub',$1,false)",[user(n)]);
  try { return await action(); }
  finally { await db.exec('reset role'); }
}
async function profile(n, context=null, offset=0) {
  return (await query('select public.embun_profile_get($1,$2,$3) as p',
    [user(n),context,offset]))[0].p;
}

await db.exec(`
  create role anon; create role authenticated;
  create schema auth;
  create table auth.users(id uuid primary key, raw_user_meta_data jsonb, email text);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth,public to authenticated,anon;
  create table public.games(id uuid primary key,status text,winner text,day integer);
  create table public.game_players(game_id uuid references public.games(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,primary key(game_id,user_id));
  create table public.player_secrets(game_id uuid references public.games(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,role text,
    primary key(game_id,user_id));
`);
for(let n=1;n<=4;n++) await query(
  'insert into auth.users values($1,$2,$3)',[user(n),
    {embun_nickname:`Pemain ${n}`,embun_avatar:'penjaga_hayu'},`private${n}@example.test`]);
// Existing finished data must not be guessed/backfilled.
await query("insert into public.games values($1,'finished','warga',2)",[room(0)]);
await query("insert into public.player_secrets values($1,$2,'warga')",[room(0),user(1)]);
const migration = readFileSync(process.argv[2], 'utf8');
await db.exec(migration);
equal((await query('select count(*)::int n from public.embun_profile_matches'))[0].n,0);

for(let n=1;n<=3;n++) await query(
  "insert into public.games values($1,'lobby',null,1)",[room(n)]);
for(const n of [1,2,3]) await query('insert into public.game_players values($1,$2)',[room(1),user(n)]);

await asUser(1, async()=>{
  let p = await profile(1); equal(p.completed,0); equal(p.history,[]);
  // Same-room lobby access works; never leaks account email or request status.
  p = await profile(2,room(1)); equal(p.nickname,'Pemain 2');
  equal(Object.hasOwn(p,'email'),false); equal(Object.hasOwn(p,'deletion_request'),false);
  await reject(()=>profile(2));
  await reject(()=>profile(4,room(1)));
  await reject(()=>profile(1,null,-1),'22023');
  await reject(()=>query('select * from public.embun_profile_participants'));
  await reject(()=>query("insert into public.embun_profile_matches values($1,$2,now(),'warga','warga',1)",[room(2),user(1)]));
  await reject(()=>query('select public.embun_profile_finish_match()'));
  await query("select public.embun_profile_title('Dermawan Hayu')");
  equal((await profile(1)).title,'Dermawan Hayu');
  await reject(()=>query("select public.embun_profile_title('Invented winner')"),'22023');
  await query('select public.embun_profile_request_deletion()');
  await query('select public.embun_profile_request_deletion()');
  equal((await profile(1)).deletion_request.status,'pending');
});
equal((await query('select count(*)::int n from public.embun_profile_deletion_requests'))[0].n,1);
await asUser(2,async()=>equal(Object.hasOwn(await profile(1,room(1)),'deletion_request'),false));
await asUser(4,async()=>{ await reject(()=>profile(1,room(1))); });
await db.exec('set role anon');
await reject(()=>query('select public.embun_profile_get($1,null,0)',[user(1)]));
await db.exec('reset role');

// First side persists when a role disappears or is revived as a villager.
for(const [n,side] of [[1,'warga'],[2,'antagonis'],[3,'warga']])
  await query('insert into public.player_secrets values($1,$2,$3)',[room(1),user(n),side]);
await query("update public.games set status='playing' where id=$1",[room(1)]);
await asUser(1,async()=>{ await reject(()=>profile(2,room(1))); });
await query('delete from public.player_secrets where game_id=$1 and user_id=$2',[room(1),user(2)]);
await query("insert into public.player_secrets values($1,$2,'warga')",[room(1),user(2)]);
await query('delete from public.player_secrets where game_id=$1 and user_id=$2',[room(1),user(3)]);
await db.exec(`begin;
  update public.games set status='finished',winner='warga',day=2 where id='${room(1)}';
  update public.games set day=7 where id='${room(1)}';
  commit;`);
await asUser(1,async()=>{
  const p=await profile(1); equal(p.completed,1); equal(p.warga_wins,1); equal(p.history[0].days,7);
  equal((await profile(2,room(1))).history[0].side,'antagonis');
});
await asUser(3,async()=>equal((await profile(3)).completed,1));
await db.exec(`begin;
  update public.games set status='playing' where id='${room(1)}';
  update public.games set status='finished' where id='${room(1)}'; commit;`);
await asUser(1,async()=>equal((await profile(1)).completed,1));

// Two antagonists both earn their side's win, not merely the surviving one.
for(const n of [1,2]) await query("insert into public.player_secrets values($1,$2,'antagonis')",[room(2),user(n)]);
await query("update public.games set status='finished',winner='antagonis' where id=$1",[room(2)]);
await asUser(1,async()=>{ const p=await profile(1);equal(p.completed,2);equal(p.terbisik_wins,1); });
await asUser(2,async()=>equal((await profile(2)).terbisik_wins,1));
await query("insert into public.player_secrets values($1,$2,'warga')",[room(3),user(1)]);
await query("update public.games set status='finished',winner='dibatalkan' where id=$1",[room(3)]);
await asUser(1,async()=>equal((await profile(1)).completed,2));

// Reapplying migration is safe, and cleaning old rooms retains account history.
await db.exec(migration);
await query('delete from public.games where id=$1',[room(1)]);
await asUser(1,async()=>equal((await profile(1)).completed,2));
for(let n=10;n<32;n++){
  await query("insert into public.games values($1,'playing',null,3)",[room(n)]);
  await query("insert into public.player_secrets values($1,$2,'warga')",[room(n),user(1)]);
  await query("update public.games set status='finished',winner='warga' where id=$1",[room(n)]);
}
await asUser(1,async()=>{
  const p=await profile(1);equal(p.completed,24);equal(p.history.length,20);equal(p.has_more,true);
  const q=await profile(1,null,20);equal(q.history.length,4);equal(q.has_more,false);
  equal(new Set([...p.history,...q.history].map(x=>x.game_id)).size,24);
});
await query('delete from auth.users where id=$1',[user(1)]);
for(const table of ['settings','matches','participants','deletion_requests'])
  equal((await query(`select count(*)::int n from public.embun_profile_${table} where user_id=$1`,[user(1)]))[0].n,0);


// Guest/Google migration upgrade tests.
await db.exec(`alter table auth.users add column is_anonymous boolean default false;
  create table auth.identities(user_id uuid references auth.users(id) on delete cascade,
    provider text,primary key(user_id,provider));
  alter table public.game_players add column name text not null default 'Pemain';`);
for(const n of [2,3,4]) await query("insert into auth.identities values($1,'google')",[user(n)]);
for(let n=50;n<=55;n++) await query(
  'insert into auth.users(id,raw_user_meta_data,email,is_anonymous) values($1,$2,$3,$4)',
  [user(n),{embun_nickname:`Pemain ${n}`,embun_avatar:'penjaga_hayu',provider:'google'},
   n===50?'private@example.test':null,[51,54].includes(n)]);
await query("insert into auth.identities values($1,'google')",[user(50)]);
// A previous guest result created by the older profile patch stays unrecorded.
await query("insert into public.embun_profile_matches(game_id,user_id,side,winner,days) values($1,$2,'warga','warga',2)",[room(90),user(51)]);
const guestMigration=readFileSync(process.argv[3],'utf8');
await db.exec(guestMigration);
await query("insert into public.games values($1,'lobby',null,1)",[room(50)]);
for(let n=50;n<=54;n++) await query('insert into public.game_players(game_id,user_id,name) values($1,$2,$3)',[room(50),user(n),`Nama Ruangan ${n}`]);
await asUser(50,async()=>{
  const p=await profile(51,room(50));equal(p.google_linked,false);
  equal(p.nickname,'Nama Ruangan 51');equal(p.history,[]);equal(p.completed,0);
  equal(Object.hasOwn(p,'email'),false);equal(Object.hasOwn(p,'deletion_request'),false);
  const links=(await query('select public.embun_profile_links($1) as p',[room(50)]))[0].p;
  equal(links.map(x=>x.google_linked),[true,false,false,false,false]);
  await reject(()=>query('select public.embun_profile_has_google($1)',[user(51)]));
});
await asUser(51,async()=>{
  await reject(()=>query("select public.embun_profile_title('Mata Elang')"));
  await reject(()=>query('select public.embun_profile_request_deletion()'));
});
await asUser(55,async()=>await reject(()=>query('select public.embun_profile_links($1)',[room(50)])));
await query("insert into public.player_secrets values($1,$2,'warga')",[room(50),user(50)]);
await query("insert into public.player_secrets values($1,$2,'antagonis')",[room(50),user(51)]);
await query("update public.games set status='playing' where id=$1",[room(50)]);
await asUser(51,async()=>{
  await reject(()=>profile(50,room(50)));
  await reject(()=>query('select public.embun_profile_links($1)',[room(50)]));
});
await query("update public.games set status='finished',winner='antagonis' where id=$1",[room(50)]);
await asUser(50,async()=>equal((await profile(50)).completed,1));
await query('update auth.users set is_anonymous=false where id=$1',[user(51)]);
await query("insert into auth.identities values($1,'google')",[user(51)]);
await asUser(51,async()=>{const p=await profile(51);equal(p.google_linked,true);equal(p.completed,0);equal(p.history,[]);});
// Re-running an installed migration must not import that guest history.
await db.exec(guestMigration);
await asUser(51,async()=>equal((await profile(51)).completed,0));
await query("insert into public.games values($1,'playing',null,3)",[room(51)]);
await query("insert into public.player_secrets values($1,$2,'antagonis')",[room(51),user(51)]);
await query("update public.games set status='finished',winner='antagonis' where id=$1",[room(51)]);
await asUser(51,async()=>{const p=await profile(51);equal(p.completed,1);equal(p.terbisik_wins,1);equal(p.history[0].game_id,room(51));});
// Linking mid-match only starts saving the next game.
await query("insert into public.games values($1,'playing',null,3)",[room(52)]);
await query("insert into public.player_secrets values($1,$2,'warga')",[room(52),user(54)]);
await query('update auth.users set is_anonymous=false where id=$1',[user(54)]);
await query("insert into auth.identities values($1,'google')",[user(54)]);
await query("update public.games set status='finished',winner='warga' where id=$1",[room(52)]);
await asUser(54,async()=>equal((await profile(54)).completed,0));
await asUser(2,async()=>equal((await profile(2)).completed,2));

await db.exec(`create table public.player_usernames(game_id uuid,user_id uuid,username text,
  primary key(game_id,user_id));`);
await query('insert into public.player_usernames values($1,$2,$3)',[room(50),user(53),'Budi Santoso']);
await query("update public.game_players set name='Peternak Telur' where game_id=$1 and user_id=$2",[room(50),user(53)]);
await query("update auth.users set raw_user_meta_data=raw_user_meta_data || $2::jsonb where id=$1",[user(50),JSON.stringify({embun_avatar:'peramu_bunga'})]);
const avatarMigration=readFileSync(process.argv[4],'utf8');
await db.exec(avatarMigration);
await asUser(50,async()=>{
  const rows=(await query('select public.embun_profile_links($1) as p',[room(50)]))[0].p;
  const a=rows.find(x=>x.user_id===user(50)),b=rows.find(x=>x.user_id===user(53));
  equal(a.google_linked,true);equal(a.avatar_id,'peramu_bunga');
  equal(b.google_linked,false);equal(b.avatar_id,null);equal(b.nickname,'Budi Santoso');
  equal(Object.keys(a).sort(),['avatar_id','google_linked','nickname','user_id']);
  equal((await profile(53,room(50))).nickname,'Budi Santoso');
});
await asUser(55,async()=>await reject(()=>query('select public.embun_profile_links($1)',[room(50)])));
await query("update public.games set status='playing' where id=$1",[room(50)]);
await asUser(50,async()=>await reject(()=>query('select public.embun_profile_links($1)',[room(50)])));
await query("update public.games set status='finished' where id=$1",[room(50)]);
await db.exec(avatarMigration);
await asUser(50,async()=>equal((await profile(50)).completed,1));
console.log(JSON.stringify({passed:checks,engine:'PGlite 0.5.17 / PostgreSQL',productionAccess:false}));
await db.close();

