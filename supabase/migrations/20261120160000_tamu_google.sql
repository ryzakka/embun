-- Guest / Google accounts. Apply after 20261120120000_profil_pemain.sql.
-- Preserves existing game RPCs and source game records; no Auth data is deleted.
begin;
create or replace function public.embun_profile_has_google(p_user uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.users u where u.id=p_user
    and not coalesce(u.is_anonymous,false)
    and exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google'));
$$;

-- Mark historical rows once. Reapplying must never promote old guest results
-- merely because that guest has subsequently linked a Google identity.
do $$ begin
  if not exists(select 1 from information_schema.columns where table_schema='public'
    and table_name='embun_profile_participants' and column_name='google_eligible') then
    alter table public.embun_profile_participants add column google_eligible boolean not null default false;
    update public.embun_profile_participants set google_eligible=true
      where public.embun_profile_has_google(user_id);
  end if;
  if not exists(select 1 from information_schema.columns where table_schema='public'
    and table_name='embun_profile_matches' and column_name='google_eligible') then
    alter table public.embun_profile_matches add column google_eligible boolean not null default false;
    update public.embun_profile_matches set google_eligible=true
      where public.embun_profile_has_google(user_id);
  end if;
end $$;

create or replace function public.embun_profile_capture_side() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.role in ('warga','antagonis') then
    insert into public.embun_profile_participants(game_id,user_id,side,google_eligible)
      values(new.game_id,new.user_id,new.role::text,public.embun_profile_has_google(new.user_id))
      on conflict(game_id,user_id) do nothing;
  end if;
  return new;
end $$;
create or replace function public.embun_profile_finish_match() returns trigger
language plpgsql security definer set search_path='' as $$
declare g record;
begin
  -- Read final transaction state, after legacy role-restoration triggers.
  select id,status,winner,day into g from public.games where id=new.id;
  if not found or g.status<>'finished' or g.winner is null
     or g.winner not in ('warga','antagonis') then return new; end if;
  insert into public.embun_profile_matches(game_id,user_id,side,winner,days,google_eligible)
    select p.game_id,p.user_id,p.side,g.winner::text,greatest(coalesce(g.day,0),0),true
    from public.embun_profile_participants p where p.game_id=g.id and p.google_eligible and public.embun_profile_has_google(p.user_id)
    on conflict(game_id,user_id) do nothing;
  return new;
end $$;
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
  if not public.embun_profile_has_google(p_user) then
    if not exists(select 1 from auth.users where id=p_user) then
      raise exception 'Akun tidak ditemukan' using errcode='P0002';
    end if;
    return jsonb_build_object('user_id',p_user,'google_linked',false,
      'nickname',coalesce((select p.name from public.game_players p
        where p.game_id=p_game and p.user_id=p_user),'Pemain tamu'),
      'avatar_id','guest','title','','completed',0,'warga_wins',0,
      'terbisik_wins',0,'has_more',false,'history','[]'::jsonb);
  end if;
  select coalesce(raw_user_meta_data,'{}'::jsonb) into meta from auth.users where id=p_user;
  if not found then raise exception 'Akun tidak ditemukan' using errcode='P0002'; end if;
  select title into selected_title from public.embun_profile_settings where user_id=p_user;
  select count(*),count(*) filter(where side='warga' and winner='warga'),
    count(*) filter(where side='antagonis' and winner='antagonis') into n,w,a
    from public.embun_profile_matches where user_id=p_user and google_eligible;
  result := jsonb_build_object(
    'user_id',p_user,'google_linked',true,
    'nickname',coalesce(nullif(left(meta->>'embun_nickname',1000),''),'Pemain Embun'),
    'avatar_id',coalesce(meta->>'embun_avatar','penjaga_hayu'),
    'title',coalesce(selected_title,''),
    'completed',n,'warga_wins',w,'terbisik_wins',a,
    'has_more',p_offset::bigint+20<n,
    'history',coalesce((select jsonb_agg(jsonb_build_object(
      'game_id',h.game_id,'finished_at',h.finished_at,'side',h.side,
      'won',h.side=h.winner,'days',h.days) order by h.finished_at desc,h.game_id desc)
      from (select * from public.embun_profile_matches where user_id=p_user and google_eligible
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
  if not public.embun_profile_has_google(auth.uid()) then raise exception 'Tautkan akun Google terlebih dahulu' using errcode='42501'; end if;
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
  if not public.embun_profile_has_google(auth.uid()) then raise exception 'Tautkan akun Google terlebih dahulu' using errcode='42501'; end if;
  if auth.uid() is null then raise exception 'Silakan masuk terlebih dahulu' using errcode='42501'; end if;
  insert into public.embun_profile_deletion_requests(user_id) values(auth.uid())
    on conflict(user_id) where status='pending' do nothing;
end $$;


create or replace function public.embun_profile_links(p_game uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.games g where g.id=p_game
    and g.status in ('lobby','finished') and exists(select 1 from public.game_players p
      where p.game_id=g.id and p.user_id=auth.uid())) then
    raise exception 'Daftar akun hanya tersedia di lobi atau hasil akhir ruangan yang sama' using errcode='42501';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id',p.user_id,
    'google_linked',public.embun_profile_has_google(p.user_id)) order by p.user_id)
    from public.game_players p where p.game_id=p_game),'[]'::jsonb);
end $$;
revoke all on function public.embun_profile_has_google(uuid),public.embun_profile_links(uuid)
  from public,anon,authenticated;
grant execute on function public.embun_profile_links(uuid) to authenticated;
commit;
