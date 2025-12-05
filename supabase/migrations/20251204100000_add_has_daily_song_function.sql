-- Migration: Add function to check if a user has selected a daily song today
-- This function bypasses RLS to allow checking if ANY user has picked a song today,
-- without revealing the actual song content.

CREATE OR REPLACE FUNCTION has_daily_song_today(check_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM shares
    WHERE sender_id = check_user_id
      AND is_daily_song = true
      AND selected_date = CURRENT_DATE
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION has_daily_song_today(UUID) TO authenticated;
