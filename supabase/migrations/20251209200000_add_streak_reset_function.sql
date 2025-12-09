-- Migration: Fix streak logic
-- Description: Fixes the streak trigger and adds client-side validation helpers
-- The iOS app uses effectiveStreak (client-side) to show 0 for expired streaks
-- The DB trigger resets streak to 1 when a user posts after missing days
-- No cron job needed - lazy evaluation handles everything
-- Date: 2025-12-09

-- ============================================
-- 1. FIX THE EXISTING STREAK TRIGGER
-- ============================================

-- The existing trigger has a bug: when last_song_date = selected_date (same day),
-- it doesn't update the streak at all. This is correct for preventing double-counting,
-- but we should also handle the edge case where someone changes their daily song.
-- Additionally, fix the logic for streak continuation.

CREATE OR REPLACE FUNCTION update_daily_song_streak() RETURNS TRIGGER AS $$
DECLARE
    last_song_date date;
    current_streak integer;
BEGIN
    -- Only process if this is a daily song
    IF NEW.is_daily_song = true THEN
        SELECT last_daily_song_date, daily_song_streak INTO last_song_date, current_streak
        FROM users WHERE id = NEW.sender_id;

        IF last_song_date IS NULL THEN
            -- First ever daily song - start streak at 1
            UPDATE users
            SET daily_song_streak = 1,
                last_daily_song_date = NEW.selected_date
            WHERE id = NEW.sender_id;
        ELSIF last_song_date = NEW.selected_date THEN
            -- Same day - already posted today, don't change streak
            -- (This handles changing your daily song within the same day)
            NULL;
        ELSIF last_song_date = NEW.selected_date - INTERVAL '1 day' THEN
            -- Posted yesterday - continue streak
            UPDATE users
            SET daily_song_streak = COALESCE(current_streak, 0) + 1,
                last_daily_song_date = NEW.selected_date
            WHERE id = NEW.sender_id;
        ELSE
            -- Missed one or more days - reset streak to 1
            UPDATE users
            SET daily_song_streak = 1,
                last_daily_song_date = NEW.selected_date
            WHERE id = NEW.sender_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. IMMEDIATE BACKFILL: RESET BROKEN STREAKS
-- ============================================

-- Reset streaks for all users who have already missed days
-- This is a one-time fix for existing data
UPDATE users
SET daily_song_streak = 0
WHERE last_daily_song_date IS NOT NULL
  AND last_daily_song_date < CURRENT_DATE - INTERVAL '1 day'
  AND daily_song_streak > 0;

-- ============================================
-- Migration Complete!
-- ============================================
--
-- How streak validation works (no cron needed):
-- 1. iOS client uses `effectiveStreak` computed property which returns 0
--    if lastDailySongDate is more than 1 day ago
-- 2. When a user posts after missing days, the DB trigger resets streak to 1
-- 3. This "lazy evaluation" approach means no background jobs are needed
--
