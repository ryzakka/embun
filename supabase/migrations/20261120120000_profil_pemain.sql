-- Embun: additive account/profile storage. Run once in the SQL Editor.
-- Does not replace any existing game RPC or change OAuth configuration.
begin;

create table if not exists public.embun_profile_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null default '' check (title in ('','Mata Elang','Paling Dicurigai',
    'Salah Sasaran','Dermawan Hayu','Pembelanja Ulung','Dalang Kabut',
    'Tak Pernah Meleset','Paling Ragu','Bayang Lolos'))
);

-- Private ledger: preserve the INITIAL side, even after elimination/revival.
-- Never expose this table or these functions to game clients.
create table if not exists public.embun_profile_participants (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  side text not null check (side in ('warga','antagonis')),
  primary key (game_id,user_id)
);

-- No FK to games: deleting an old room must not erase account history.
create table if not exists public.embun_profile_matches (
  game_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  finished_at timestamptz not null default now(),
  side text not null check (side in ('warga','antagonis')),
  winner text not null check (winner in ('warga','antagonis')),
  days integer not null check (days >= 0),
  primary key (game_id,user_id)
);
create index if not exists embun_profile_matches_user_date
  on public.embun_profile_matches(user_id,finished_at desc,game_id desc);

create table if not exists public.embun_profile_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now(),
  status text not null default 'pending' check (status in ('pending','reviewed'))
);
create unique index if not exists embun_profile_one_pending_deletion
  on public.embun_profile_deletion_requests(user_id) where status='pending';

alter table public.embun_profile_settings enable row level security;
alter table public.embun_profile_participants enable row level security;
alter table public.embun_profile_matches enable row level security;
alter table public.embun_profile_deletion_requests enable row level security;
revoke all on public.embun_profile_settings, public.embun_profile_participants,
  public.embun_profile_matches,public.embun_profile_deletion_requests
  from public,anon,authenticated;

create or replace function public.embun_profile_capture_side() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.role in ('warga','antagonis') then
    insert into public.embun_profile_participants(game_id,user_id,side)
      values(new.game_id,new.user_id,new.role::text)
      on conflict(game_id,user_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists embun_profile_capture_side on public.player_secrets;
create trigger embun_profile_capture_side after insert or update of role
  on public.player_secrets for each row
  execute function public.embun_profile_capture_side();

create or replace function public.embun_profile_finish_match() returns trigger
language plpgsql security definer set search_path='' as $$
declare g record;
begin
  -- Read final transaction state, after legacy role-restoration triggers.
  select id,status,winner,day into g from public.games where id=new.id;
  if not found or g.status<>'finished' or g.winner is null
     or g.winner not in ('warga','antagonis') then return new; end if;
  insert into public.embun_profile_matches(game_id,user_id,side,winner,days)
    select p.game_id,p.user_id,p.side,g.winner::text,greatest(coalesce(g.day,0),0)
    from public.embun_profile_participants p where p.game_id=g.id
    on conflict(game_id,user_id) do nothing;
  return new;
end $$;
drop trigger if exists embun_profile_finish_match on public.games;
create constraint trigger embun_profile_finish_match after update on public.games
  deferrable initially deferred for each row
  when (new.status='finished' and old.status is distinct from new.status)
  execute function public.embun_profile_finish_match();

-- Only seed unfinished rooms with known roles. Do not invent historical roles
-- or count older finished matches whose complete participants are unknown.
insert into public.embun_profile_participants(game_id,user_id,side)
  select s.game_id,s.user_id,s.role::text from public.player_secrets s
  join public.games g on g.id=s.game_id
  where g.status<>'finished' and s.role in ('warga','antagonis')
  on conflict(game_id,user_id) do nothing;

create or replace function public.embun_profile_get(
  p_user uuid, p_game uuid default null, p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid(); meta jsonb; result jsonb;
  n bigint; w bigint; a bigint; selected_title text;
begin
  if actor is null then raise exception 'Silakan masuk terlebih dahulu' using errcode='42501'; end if;
  if p_user is null or p_offset is null or p_offset<0 then
    raise exception 'Parameter profil tidak valid' using errcode='22023';
  end if;
  if p_user<>actor and not exists (
    select 1 from public.games g
    where g.id=p_game and g.status in ('lobby','finished')
      and exists(select 1 from public.game_players p where p.game_id=g.id and p.user_id=actor)
      and exists(select 1 from public.game_players p where p.game_id=g.id and p.user_id=p_user)
  ) then raise exception 'Profil hanya tersedia di lobi atau hasil akhir ruangan yang sama' using errcode='42501'; end if;
  select coalesce(raw_user_meta_data,'{}'::jsonb) into meta from auth.users where id=p_user;
  if not found then raise exception 'Akun tidak ditemukan' using errcode='P0002'; end if;
  select title into selected_title from public.embun_profile_settings where user_id=p_user;
  select count(*),count(*) filter(where side='warga' and winner='warga'),
    count(*) filter(where side='antagonis' and winner='antagonis') into n,w,a
    from public.embun_profile_matches where user_id=p_user;
  result := jsonb_build_object(
    'user_id',p_user,
    'nickname',coalesce(nullif(left(meta->>'embun_nickname',1000),''),'Pemain Embun'),
    'avatar_id',coalesce(meta->>'embun_avatar','penjaga_hayu'),
    'title',coalesce(selected_title,''),
    'completed',n,'warga_wins',w,'terbisik_wins',a,
    'has_more',p_offset::bigint+20<n,
    'history',coalesce((select jsonb_agg(jsonb_build_object(
      'game_id',h.game_id,'finished_at',h.finished_at,'side',h.side,
      'won',h.side=h.winner,'days',h.days) order by h.finished_at desc,h.game_id desc)
      from (select * from public.embun_profile_matches where user_id=p_user
        order by finished_at desc,game_id desc limit 20 offset p_offset) h),'[]'::jsonb)
  );
  if p_user=actor then
    result := result || jsonb_build_object('deletion_request',(
      select jsonb_build_object('id',id,'requested_at',requested_at,'status',status)
      from public.embun_profile_deletion_requests where user_id=actor
      order by requested_at desc,id desc limit 1));
  end if;
  return result;
end $$;

create or replace function public.embun_profile_title(p_title text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Silakan masuk terlebih dahulu' using errcode='42501'; end if;
  if p_title is null or p_title not in ('','Mata Elang','Paling Dicurigai',
    'Salah Sasaran','Dermawan Hayu','Pembelanja Ulung','Dalang Kabut',
    'Tak Pernah Meleset','Paling Ragu','Bayang Lolos') then
    raise exception 'Gelar tidak valid' using errcode='22023';
  end if;
  insert into public.embun_profile_settings(user_id,title) values(auth.uid(),p_title)
    on conflict(user_id) do update set title=excluded.title;
end $$;

create or replace function public.embun_profile_request_deletion() returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Silakan masuk terlebih dahulu' using errcode='42501'; end if;
  insert into public.embun_profile_deletion_requests(user_id) values(auth.uid())
    on conflict(user_id) where status='pending' do nothing;
end $$;

revoke all on function public.embun_profile_capture_side(),
  public.embun_profile_finish_match(), public.embun_profile_get(uuid,uuid,integer),
  public.embun_profile_title(text), public.embun_profile_request_deletion()
  from public,anon,authenticated;
grant execute on function public.embun_profile_get(uuid,uuid,integer),
  public.embun_profile_title(text),public.embun_profile_request_deletion()
  to authenticated;
commit;
