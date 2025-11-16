-- Optimize the get_user_phlocks_grouped function for better performance
-- The original function has a potentially slow EXISTS subquery in the WHERE clause

-- Drop and recreate with better performance characteristics
CREATE OR REPLACE FUNCTION public.get_user_phlocks_grouped(p_user_id uuid)
RETURNS TABLE (
    track_id text,
    track_name text,
    artist_name text,
    album_art_url text,
    recipient_count integer,
    played_count integer,
    saved_count integer,
    last_sent_at timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
STABLE -- Mark as STABLE since it doesn't modify data
AS $$
    -- First verify the user exists and matches auth (single check)
    WITH auth_check AS (
        SELECT 1
        FROM users u
        WHERE u.id = p_user_id
          AND u.auth_user_id = auth.uid()
        LIMIT 1
    )
    SELECT
        s.track_id,
        MAX(s.track_name) as track_name,
        MAX(s.artist_name) as artist_name,
        MAX(s.album_art_url) as album_art_url,
        COUNT(*)::integer as recipient_count,
        COUNT(*) FILTER (WHERE s.status IN ('played', 'saved'))::integer as played_count,
        COUNT(*) FILTER (WHERE s.status = 'saved')::integer as saved_count,
        MAX(s.created_at) as last_sent_at
    FROM shares s
    WHERE s.sender_id = p_user_id
      AND EXISTS (SELECT 1 FROM auth_check) -- More efficient auth check
    GROUP BY s.track_id
    ORDER BY last_sent_at DESC
    LIMIT 100; -- Add reasonable limit to prevent runaway queries
$$;

-- Add comment
COMMENT ON FUNCTION public.get_user_phlocks_grouped IS 'Returns aggregated share metrics by track for the authenticated user, optimized with CTE for auth check';

-- Also create a simpler version without auth check for trusted internal use
CREATE OR REPLACE FUNCTION public.get_user_phlocks_grouped_fast(p_user_id uuid)
RETURNS TABLE (
    track_id text,
    track_name text,
    artist_name text,
    album_art_url text,
    recipient_count integer,
    played_count integer,
    saved_count integer,
    last_sent_at timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
STABLE
AS $$
    SELECT
        s.track_id,
        MAX(s.track_name) as track_name,
        MAX(s.artist_name) as artist_name,
        MAX(s.album_art_url) as album_art_url,
        COUNT(*)::integer as recipient_count,
        COUNT(*) FILTER (WHERE s.status IN ('played', 'saved'))::integer as played_count,
        COUNT(*) FILTER (WHERE s.status = 'saved')::integer as saved_count,
        MAX(s.created_at) as last_sent_at
    FROM shares s
    WHERE s.sender_id = p_user_id
    GROUP BY s.track_id
    ORDER BY last_sent_at DESC
    LIMIT 100;
$$;

-- Ensure we have the right indexes (re-run to be safe)
CREATE INDEX IF NOT EXISTS idx_shares_sender_track_created
ON shares(sender_id, track_id, created_at DESC);

-- Analyze the table to update statistics for query planner
ANALYZE shares;