-- Migration: Create share_likes table for social like functionality
-- This enables users to like daily song shares from their phlock members

-- Create share_likes table
CREATE TABLE IF NOT EXISTS share_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_id UUID NOT NULL REFERENCES shares(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One like per user per share
    CONSTRAINT unique_share_like UNIQUE(share_id, user_id)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_share_likes_share_id ON share_likes(share_id);
CREATE INDEX IF NOT EXISTS idx_share_likes_user_id ON share_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_share_likes_created_at ON share_likes(created_at DESC);

-- Add like_count column to shares table
ALTER TABLE shares ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0;

-- Create index on like_count for sorting
CREATE INDEX IF NOT EXISTS idx_shares_like_count ON shares(like_count DESC);

-- Enable RLS
ALTER TABLE share_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for share_likes

-- Users can view likes on shares they can see (any daily song - phlock members check is complex)
-- Simplified policy: allow viewing likes on any share for now
-- The app-level logic already restricts which shares are shown to users
CREATE POLICY "Users can view likes on shares"
    ON share_likes
    FOR SELECT
    USING (
        -- User can see likes on shares where they are sender/recipient
        EXISTS (
            SELECT 1 FROM shares s
            WHERE s.id = share_likes.share_id
            AND (s.sender_id = auth.uid() OR s.recipient_id = auth.uid())
        )
        OR
        -- Or they can see likes on any daily song (phlock logic is app-side)
        EXISTS (
            SELECT 1 FROM shares s
            WHERE s.id = share_likes.share_id
            AND s.is_daily_song = true
        )
    );

-- Users can like shares they can view (any daily song)
CREATE POLICY "Users can like visible shares"
    ON share_likes
    FOR INSERT
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM shares s
            WHERE s.id = share_likes.share_id
            AND (
                s.sender_id = auth.uid()
                OR s.recipient_id = auth.uid()
                OR s.is_daily_song = true
            )
        )
    );

-- Users can only delete their own likes
CREATE POLICY "Users can unlike their own likes"
    ON share_likes
    FOR DELETE
    USING (user_id = auth.uid());

-- Function to update like_count on shares
CREATE OR REPLACE FUNCTION update_share_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE shares
        SET like_count = like_count + 1
        WHERE id = NEW.share_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE shares
        SET like_count = GREATEST(0, like_count - 1)
        WHERE id = OLD.share_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to maintain like_count
DROP TRIGGER IF EXISTS update_share_like_count_trigger ON share_likes;
CREATE TRIGGER update_share_like_count_trigger
    AFTER INSERT OR DELETE ON share_likes
    FOR EACH ROW
    EXECUTE FUNCTION update_share_like_count();

-- Add new notification types for social engagement
-- First, get the current check constraint and drop it
DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

    -- Add updated constraint with new types
    ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
        CHECK (type IN (
            'daily_nudge',
            'new_follower',
            'follow_request_received',
            'follow_request_accepted',
            'friend_joined',
            'phlock_song_ready',
            'song_played',
            'song_saved',
            'streak_milestone',
            'share_liked',
            'share_commented'
        ));
EXCEPTION
    WHEN others THEN
        -- If constraint doesn't exist or other error, just add the new one
        ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
            CHECK (type IN (
                'daily_nudge',
                'new_follower',
                'follow_request_received',
                'follow_request_accepted',
                'friend_joined',
                'phlock_song_ready',
                'song_played',
                'song_saved',
                'streak_milestone',
                'share_liked',
                'share_commented'
            ));
END $$;

-- Add send_count column to shares for tracking forwards
ALTER TABLE shares ADD COLUMN IF NOT EXISTS send_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON TABLE share_likes IS 'Tracks likes on shared songs - social engagement feature';
COMMENT ON COLUMN shares.like_count IS 'Cached count of likes for this share';
COMMENT ON COLUMN shares.send_count IS 'Cached count of times this share was forwarded';
