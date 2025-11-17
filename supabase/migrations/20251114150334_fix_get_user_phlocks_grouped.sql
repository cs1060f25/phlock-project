-- Ensure we only scope results to the authenticated user's app-level ID
create or replace function public.get_user_phlocks_grouped(p_user_id uuid)
returns table (
    track_id text,
    track_name text,
    artist_name text,
    album_art_url text,
    recipient_count integer,
    played_count integer,
    saved_count integer,
    last_sent_at timestamptz
) security definer
set search_path = public
language sql
as $$
    select
        s.track_id,
        max(s.track_name) as track_name,
        max(s.artist_name) as artist_name,
        max(s.album_art_url) as album_art_url,
        count(*)::integer as recipient_count,
        count(*) filter (where s.status in ('played', 'saved'))::integer as played_count,
        count(*) filter (where s.status = 'saved')::integer as saved_count,
        max(s.created_at) as last_sent_at
    from shares s
    where s.sender_id = p_user_id
      and exists (
        select 1
        from users u
        where u.id = p_user_id
          and u.auth_user_id = auth.uid()
      )
    group by s.track_id
    order by last_sent_at desc;
$$;
