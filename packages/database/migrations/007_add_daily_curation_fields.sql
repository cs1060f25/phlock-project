-- Migration 007: Add Daily Curation Fields (Incremental Approach)
-- Description: Extend existing tables to support daily curation model
-- Date: 2025-11-22
-- Strategy: Non-breaking changes, additive only

-- ============================================
-- 1. EXTEND USERS TABLE
-- ============================================

-- Add daily curation fields to existing users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS username text UNIQUE,
ADD COLUMN IF NOT EXISTS phlock_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS daily_song_streak integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_daily_song_date date;

-- Add index for username searches
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_phlock_count ON users(phlock_count DESC);

-- ============================================
-- 2. EXTEND SHARES TABLE FOR DAILY SONGS
-- ============================================

-- Add fields to support daily song selection
ALTER TABLE shares
ADD COLUMN IF NOT EXISTS is_daily_song boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS selected_date date,
ADD COLUMN IF NOT EXISTS preview_url text;

-- Add index for daily song queries
CREATE INDEX IF NOT EXISTS idx_shares_daily_songs
ON shares(sender_id, selected_date)
WHERE is_daily_song = true;

CREATE INDEX IF NOT EXISTS idx_shares_selected_date
ON shares(selected_date DESC)
WHERE is_daily_song = true;

-- ============================================
-- 3. EXTEND FRIENDSHIPS TABLE FOR PHLOCK
-- ============================================

-- Add fields to support phlock positions and swapping
ALTER TABLE friendships
ADD COLUMN IF NOT EXISTS position integer,
ADD COLUMN IF NOT EXISTS is_phlock_member boolean DEFAULT true,
ADD COLUMN IF NOT EXISTS last_swapped_at timestamptz;

-- Create index for position-based queries
CREATE INDEX IF NOT EXISTS idx_friendships_position
ON friendships(user_id_1, position)
WHERE status = 'accepted' AND is_phlock_member = true;

-- ============================================
-- 4. CREATE SWAP HISTORY TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS swap_history (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    removed_member_id uuid REFERENCES users(id) ON DELETE SET NULL,
    added_member_id uuid REFERENCES users(id) ON DELETE SET NULL,
    swap_date date NOT NULL DEFAULT CURRENT_DATE,
    position integer NOT NULL,
    reason text,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE swap_history ENABLE ROW LEVEL SECURITY;

-- RLS policies for swap_history
CREATE POLICY "Users can view their own swap history" ON swap_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own swap records" ON swap_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Index for swap history queries
CREATE INDEX IF NOT EXISTS idx_swap_history_user_date
ON swap_history(user_id, swap_date DESC);

-- ============================================
-- 5. HELPER FUNCTIONS
-- ============================================

-- Function to update phlock count when friendships change
CREATE OR REPLACE FUNCTION update_phlock_count_on_friendship() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'accepted' AND NEW.is_phlock_member = true THEN
        -- Increment phlock count for user_id_2 (member being added)
        UPDATE users SET phlock_count = phlock_count + 1 WHERE id = NEW.user_id_2;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle status or phlock member changes
        IF OLD.status != 'accepted' AND NEW.status = 'accepted' AND NEW.is_phlock_member = true THEN
            UPDATE users SET phlock_count = phlock_count + 1 WHERE id = NEW.user_id_2;
        ELSIF OLD.status = 'accepted' AND NEW.status != 'accepted' THEN
            UPDATE users SET phlock_count = GREATEST(phlock_count - 1, 0) WHERE id = NEW.user_id_2;
        ELSIF OLD.is_phlock_member = true AND NEW.is_phlock_member = false THEN
            UPDATE users SET phlock_count = GREATEST(phlock_count - 1, 0) WHERE id = NEW.user_id_2;
        ELSIF OLD.is_phlock_member = false AND NEW.is_phlock_member = true THEN
            UPDATE users SET phlock_count = phlock_count + 1 WHERE id = NEW.user_id_2;
        END IF;
    ELSIF TG_OP = 'DELETE' AND OLD.status = 'accepted' AND OLD.is_phlock_member = true THEN
        -- Decrement phlock count for user_id_2
        UPDATE users SET phlock_count = GREATEST(phlock_count - 1, 0) WHERE id = OLD.user_id_2;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for phlock count maintenance
DROP TRIGGER IF EXISTS maintain_phlock_count ON friendships;
CREATE TRIGGER maintain_phlock_count
AFTER INSERT OR UPDATE OR DELETE ON friendships
FOR EACH ROW EXECUTE FUNCTION update_phlock_count_on_friendship();

-- Function to update daily song streak
CREATE OR REPLACE FUNCTION update_daily_song_streak() RETURNS TRIGGER AS $$
DECLARE
    last_song_date date;
    current_streak integer;
BEGIN
    -- Only process if this is a daily song
    IF NEW.is_daily_song = true THEN
        SELECT last_daily_song_date, daily_song_streak INTO last_song_date, current_streak
        FROM users WHERE id = NEW.sender_id;

        IF last_song_date IS NULL OR last_song_date = NEW.selected_date - 1 THEN
            -- Continue or start streak
            UPDATE users
            SET daily_song_streak = COALESCE(current_streak, 0) + 1,
                last_daily_song_date = NEW.selected_date
            WHERE id = NEW.sender_id;
        ELSIF last_song_date < NEW.selected_date - 1 THEN
            -- Streak broken, restart
            UPDATE users
            SET daily_song_streak = 1,
                last_daily_song_date = NEW.selected_date
            WHERE id = NEW.sender_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for streak maintenance
DROP TRIGGER IF EXISTS maintain_daily_streak ON shares;
CREATE TRIGGER maintain_daily_streak
AFTER INSERT ON shares
FOR EACH ROW EXECUTE FUNCTION update_daily_song_streak();

-- Function to check daily swap limit (1 per day)
CREATE OR REPLACE FUNCTION check_daily_swap_limit() RETURNS TRIGGER AS $$
DECLARE
    swap_count integer;
BEGIN
    SELECT COUNT(*) INTO swap_count
    FROM swap_history
    WHERE user_id = NEW.user_id
    AND swap_date = CURRENT_DATE;

    IF swap_count >= 1 THEN
        RAISE EXCEPTION 'Daily swap limit reached. You can only swap one phlock member per day.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for swap limit enforcement
DROP TRIGGER IF EXISTS enforce_swap_limit ON swap_history;
CREATE TRIGGER enforce_swap_limit
BEFORE INSERT ON swap_history
FOR EACH ROW EXECUTE FUNCTION check_daily_swap_limit();

-- ============================================
-- 6. DATA MIGRATION (Optional - Backfill)
-- ============================================

-- Assign positions to existing accepted friendships
UPDATE friendships f
SET position = sub.row_num
FROM (
    SELECT
        id,
        ROW_NUMBER() OVER (PARTITION BY user_id_1 ORDER BY created_at) as row_num
    FROM friendships
    WHERE status = 'accepted'
) sub
WHERE f.id = sub.id
AND f.position IS NULL
AND sub.row_num <= 5; -- Only first 5 friends get positions

-- Calculate initial phlock counts
UPDATE users u
SET phlock_count = (
    SELECT COUNT(*)
    FROM friendships f
    WHERE f.user_id_2 = u.id
    AND f.status = 'accepted'
    AND f.is_phlock_member = true
    AND f.position IS NOT NULL
    AND f.position <= 5
);

-- ============================================
-- 7. CONSTRAINTS (Add After Testing)
-- ============================================

-- Note: These constraints can be added later once the feature is tested
-- Uncomment when ready to enforce:

-- Ensure one daily song per user per day
-- ALTER TABLE shares
-- ADD CONSTRAINT unique_daily_song_per_day
-- UNIQUE(sender_id, selected_date)
-- WHERE is_daily_song = true;

-- Ensure phlock positions are within valid range
-- ALTER TABLE friendships
-- ADD CONSTRAINT valid_phlock_position
-- CHECK (position IS NULL OR (position >= 1 AND position <= 10));

-- ============================================
-- Migration Complete!
-- ============================================

-- Summary: This migration extends existing tables to support daily curation
-- without breaking the current viral sharing functionality.
-- Both models can coexist during the transition period.