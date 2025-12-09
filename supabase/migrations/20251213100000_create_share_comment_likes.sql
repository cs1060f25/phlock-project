-- Migration: Create share_comment_likes table for liking comments
-- Similar to share_likes but for individual comments

-- Create the share_comment_likes table
CREATE TABLE IF NOT EXISTS share_comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID NOT NULL REFERENCES share_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure a user can only like a comment once
    UNIQUE(comment_id, user_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_share_comment_likes_comment_id ON share_comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_share_comment_likes_user_id ON share_comment_likes(user_id);

-- Enable RLS
ALTER TABLE share_comment_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view all likes on comments (public)
DROP POLICY IF EXISTS "Users can view all comment likes" ON share_comment_likes;
CREATE POLICY "Users can view all comment likes"
ON share_comment_likes FOR SELECT
TO authenticated
USING (true);

-- Users can like comments
DROP POLICY IF EXISTS "Users can like comments" ON share_comment_likes;
CREATE POLICY "Users can like comments"
ON share_comment_likes FOR INSERT
TO authenticated
WITH CHECK (user_id = get_current_user_id());

-- Users can unlike their own likes
DROP POLICY IF EXISTS "Users can unlike their own likes" ON share_comment_likes;
CREATE POLICY "Users can unlike their own likes"
ON share_comment_likes FOR DELETE
TO authenticated
USING (user_id = get_current_user_id());

-- Add like_count column to share_comments table
ALTER TABLE share_comments ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0;

-- Create trigger to maintain like_count
CREATE OR REPLACE FUNCTION update_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE share_comments SET like_count = like_count + 1 WHERE id = NEW.comment_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE share_comments SET like_count = like_count - 1 WHERE id = OLD.comment_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_comment_like_count ON share_comment_likes;
CREATE TRIGGER trigger_update_comment_like_count
AFTER INSERT OR DELETE ON share_comment_likes
FOR EACH ROW EXECUTE FUNCTION update_comment_like_count();

-- Add comment_liked to notifications type constraint
-- First drop the existing constraint
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Re-create with the new type included
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check CHECK (
    type IN (
        'friend_request_accepted',
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
        'share_commented',
        'comment_liked'
    )
);

COMMENT ON TABLE share_comment_likes IS 'Stores likes on comments for social engagement';
