-- Convert from mutual friendship model to unilateral follow model
-- Date: 2025-11-28
-- Description: Users can now follow others without requiring reciprocation.
--              This simplifies the social graph and allows for asymmetric relationships.
--
-- Key changes:
-- 1. Create new 'follows' table with clear follower -> following relationship
-- 2. Migrate existing accepted friendships to mutual follows
-- 3. Keep phlock logic (you can only add someone to your phlock if you follow them)

-- Create the new follows table
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Phlock fields (follower's phlock settings for following)
    -- Only the follower can add the following to their phlock
    is_in_phlock BOOLEAN DEFAULT FALSE,
    phlock_position INT CHECK (phlock_position >= 1 AND phlock_position <= 5),
    phlock_added_at TIMESTAMPTZ,

    -- Prevent duplicate follows
    UNIQUE(follower_id, following_id),

    -- Prevent self-follows
    CHECK (follower_id != following_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_follows_phlock ON follows(follower_id, is_in_phlock) WHERE is_in_phlock = true;
CREATE INDEX IF NOT EXISTS idx_follows_created_at ON follows(created_at DESC);

-- Enable RLS
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DO $$
BEGIN
    -- Anyone can view follows (public follow lists)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follows' AND policyname = 'Anyone can view follows'
    ) THEN
        CREATE POLICY "Anyone can view follows"
        ON follows FOR SELECT
        TO authenticated
        USING (true);
    END IF;

    -- Users can create their own follows
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follows' AND policyname = 'Users can follow others'
    ) THEN
        CREATE POLICY "Users can follow others"
        ON follows FOR INSERT
        TO authenticated
        WITH CHECK (follower_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    -- Users can update their own follows (for phlock settings)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follows' AND policyname = 'Users can update their follows'
    ) THEN
        CREATE POLICY "Users can update their follows"
        ON follows FOR UPDATE
        TO authenticated
        USING (follower_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    -- Users can unfollow (delete their follows)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follows' AND policyname = 'Users can unfollow'
    ) THEN
        CREATE POLICY "Users can unfollow"
        ON follows FOR DELETE
        TO authenticated
        USING (follower_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;
END $$;

-- Migrate existing accepted friendships to mutual follows
-- Each accepted friendship becomes two follow records (A follows B, B follows A)
INSERT INTO follows (follower_id, following_id, created_at, is_in_phlock, phlock_position, phlock_added_at)
SELECT
    user_id_1 as follower_id,
    user_id_2 as following_id,
    created_at,
    user_1_has_in_phlock as is_in_phlock,
    user_1_phlock_position as phlock_position,
    user_1_phlock_added_at as phlock_added_at
FROM friendships
WHERE status = 'accepted'
ON CONFLICT (follower_id, following_id) DO NOTHING;

INSERT INTO follows (follower_id, following_id, created_at, is_in_phlock, phlock_position, phlock_added_at)
SELECT
    user_id_2 as follower_id,
    user_id_1 as following_id,
    created_at,
    user_2_has_in_phlock as is_in_phlock,
    user_2_phlock_position as phlock_position,
    user_2_phlock_added_at as phlock_added_at
FROM friendships
WHERE status = 'accepted'
ON CONFLICT (follower_id, following_id) DO NOTHING;

-- Add follower/following counts to users table for quick access
ALTER TABLE users
ADD COLUMN IF NOT EXISTS follower_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INT DEFAULT 0;

-- Create function to update follower counts
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment following_count for follower
        UPDATE users SET following_count = following_count + 1 WHERE id = NEW.follower_id;
        -- Increment follower_count for following
        UPDATE users SET follower_count = follower_count + 1 WHERE id = NEW.following_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrement following_count for follower
        UPDATE users SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id;
        -- Decrement follower_count for following
        UPDATE users SET follower_count = GREATEST(0, follower_count - 1) WHERE id = OLD.following_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for follow count updates
DROP TRIGGER IF EXISTS trigger_update_follow_counts ON follows;
CREATE TRIGGER trigger_update_follow_counts
AFTER INSERT OR DELETE ON follows
FOR EACH ROW EXECUTE FUNCTION update_follow_counts();

-- Initialize counts from existing data
UPDATE users u SET
    follower_count = (SELECT COUNT(*) FROM follows f WHERE f.following_id = u.id),
    following_count = (SELECT COUNT(*) FROM follows f WHERE f.follower_id = u.id);

-- Add helpful comments
COMMENT ON TABLE follows IS 'Unilateral follow relationships. follower_id follows following_id.';
COMMENT ON COLUMN follows.is_in_phlock IS 'True if follower has added following to their phlock';
COMMENT ON COLUMN follows.phlock_position IS 'Position (1-5) in the follower phlock';
COMMENT ON COLUMN users.follower_count IS 'Cached count of users who follow this user';
COMMENT ON COLUMN users.following_count IS 'Cached count of users this user follows';
