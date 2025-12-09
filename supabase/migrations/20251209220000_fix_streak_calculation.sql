-- Migration: Fix streak calculation properly
-- Description: Recalculates all streaks correctly based on consecutive posting days
-- Date: 2025-12-09

-- The previous migration had a flawed consecutive day calculation.
-- This one properly calculates streaks by:
-- 1. Getting all daily songs per user ordered by date
-- 2. Finding gaps between consecutive posts
-- 3. Counting the current streak (days from most recent gap to today/yesterday)

-- First, let's create a function to calculate a user's streak
CREATE OR REPLACE FUNCTION calculate_user_streak(user_id_param UUID)
RETURNS INTEGER AS $$
DECLARE
    streak_count INTEGER := 0;
    last_date DATE;
    current_date_check DATE;
    rec RECORD;
BEGIN
    -- Get the user's most recent daily song date
    SELECT selected_date INTO last_date
    FROM shares
    WHERE sender_id = user_id_param
      AND is_daily_song = true
      AND selected_date IS NOT NULL
    ORDER BY selected_date DESC
    LIMIT 1;

    -- If no daily songs, streak is 0
    IF last_date IS NULL THEN
        RETURN 0;
    END IF;

    -- If the last post was more than 1 day ago, streak is broken
    IF last_date < CURRENT_DATE - INTERVAL '1 day' THEN
        RETURN 0;
    END IF;

    -- Count consecutive days backwards from the most recent post
    current_date_check := last_date;

    FOR rec IN
        SELECT DISTINCT selected_date
        FROM shares
        WHERE sender_id = user_id_param
          AND is_daily_song = true
          AND selected_date IS NOT NULL
        ORDER BY selected_date DESC
    LOOP
        IF rec.selected_date = current_date_check THEN
            streak_count := streak_count + 1;
            current_date_check := current_date_check - INTERVAL '1 day';
        ELSIF rec.selected_date < current_date_check THEN
            -- Gap found, stop counting
            EXIT;
        END IF;
    END LOOP;

    RETURN streak_count;
END;
$$ LANGUAGE plpgsql;

-- Now update all users' streaks using this function
UPDATE users u
SET daily_song_streak = calculate_user_streak(u.id)
WHERE EXISTS (
    SELECT 1 FROM shares s
    WHERE s.sender_id = u.id
    AND s.is_daily_song = true
);

-- Also ensure last_daily_song_date is correct for all users
UPDATE users u
SET last_daily_song_date = (
    SELECT MAX(selected_date)
    FROM shares s
    WHERE s.sender_id = u.id
      AND s.is_daily_song = true
      AND s.selected_date IS NOT NULL
)
WHERE EXISTS (
    SELECT 1 FROM shares s
    WHERE s.sender_id = u.id
    AND s.is_daily_song = true
);

-- Clean up: drop the helper function (optional, can keep for debugging)
-- DROP FUNCTION IF EXISTS calculate_user_streak(UUID);
