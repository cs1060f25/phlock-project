-- Migration: Restore valid streaks
-- Description: Recalculates streaks for users who posted yesterday or today
-- Date: 2025-12-09

-- Step 1: Restore streak = 1 for users who posted today or yesterday
-- (These users have valid streaks that were incorrectly reset)
UPDATE users
SET daily_song_streak = 1
WHERE last_daily_song_date IS NOT NULL
  AND last_daily_song_date >= CURRENT_DATE - INTERVAL '1 day'
  AND daily_song_streak = 0;

-- Step 2: Recalculate actual streak values by counting consecutive days
-- This CTE calculates the true streak for each user based on their posting history
WITH consecutive_days AS (
    SELECT
        sender_id,
        selected_date,
        selected_date - (ROW_NUMBER() OVER (PARTITION BY sender_id ORDER BY selected_date DESC))::int AS streak_group
    FROM shares
    WHERE is_daily_song = true
      AND selected_date IS NOT NULL
),
streak_counts AS (
    SELECT
        sender_id,
        MAX(selected_date) as last_date,
        COUNT(*) as streak_length
    FROM consecutive_days
    GROUP BY sender_id, streak_group
    HAVING MAX(selected_date) >= CURRENT_DATE - INTERVAL '1 day'
),
max_streaks AS (
    SELECT
        sender_id,
        MAX(streak_length) as calculated_streak
    FROM streak_counts
    WHERE last_date >= CURRENT_DATE - INTERVAL '1 day'
    GROUP BY sender_id
)
UPDATE users u
SET daily_song_streak = ms.calculated_streak
FROM max_streaks ms
WHERE u.id = ms.sender_id
  AND u.last_daily_song_date >= CURRENT_DATE - INTERVAL '1 day';
