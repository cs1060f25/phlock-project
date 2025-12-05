-- Migration: Fix timezone issue in has_daily_song_today function
-- The previous version used CURRENT_DATE (UTC) but the app stores selected_date
-- in the user's local timezone. This version accepts the date as a parameter.

-- Drop the old function
DROP FUNCTION IF EXISTS has_daily_song_today(UUID);

-- Create new function that accepts the date as a parameter
CREATE OR REPLACE FUNCTION has_daily_song_today(check_user_id UUID, check_date DATE DEFAULT CURRENT_DATE)
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
      AND selected_date = check_date
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION has_daily_song_today(UUID, DATE) TO authenticated;
