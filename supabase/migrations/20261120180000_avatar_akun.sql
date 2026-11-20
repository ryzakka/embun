-- Apply after 20261120160000_tamu_google.sql. Public avatars outside gameplay.
begin;
create or replace function public.embun_profile_links(p_game uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.games g where g.id=p_game
    and g.status in ('lobby','finished') and exists(select 1 from public.game_players p
      where p.game_id=g.id and p.user_id=auth.uid())) then
    raise exception 'Avatar akun hanya tersedia di lobi atau hasil akhir ruangan yang sama' using errcode='42501';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'user_id',p.user_id,
    'google_linked',public.embun_profile_has_google(p.user_id),
    'nickname',case when public.embun_profile_has_google(p.user_id)
      then coalesce(nullif(left(u.raw_user_meta_data->>'embun_nickname',1000),''),nullif(n.username,''),p.name)
      else coalesce(nullif(n.username,''),p.name) end,
    'avatar_id',case when public.embun_profile_has_google(p.user_id)
      then coalesce(u.raw_user_meta_data->>'embun_avatar','penjaga_hayu') else null end
    ) order by p.user_id)
    from public.game_players p
    left join auth.users u on u.id=p.user_id
    left join public.player_usernames n on n.game_id=p.game_id and n.user_id=p.user_id
    where p.game_id=p_game),'[]'::jsonb);
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
      'nickname',coalesce((select coalesce(nullif(n.username,''),p.name) from public.game_players p
        left join public.player_usernames n on n.game_id=p.game_id and n.user_id=p.user_id
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


revoke all on function public.embun_profile_links(uuid) from public,anon;
grant execute on function public.embun_profile_links(uuid) to authenticated;
commit;
