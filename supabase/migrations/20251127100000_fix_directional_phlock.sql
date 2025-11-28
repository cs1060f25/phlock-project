-- Fix: Make phlock membership directional (each user independently manages their own phlock)
--
-- Problem: The current schema uses shared columns (is_phlock_member, position) on the friendships table.
-- When user A adds user B to their phlock, it also appears in user B's phlock view because they share the same row.
--
-- Solution: Add user-specific columns for each direction of the friendship.
-- - user_1_has_in_phlock: true if user_id_1 has user_id_2 in their phlock
-- - user_1_phlock_position: position (1-5) in user_id_1's phlock
-- - user_2_has_in_phlock: true if user_id_2 has user_id_1 in their phlock
-- - user_2_phlock_position: position (1-5) in user_id_2's phlock

-- Add directional phlock columns
ALTER TABLE friendships
ADD COLUMN IF NOT EXISTS user_1_has_in_phlock BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS user_1_phlock_position INT CHECK (user_1_phlock_position >= 1 AND user_1_phlock_position <= 5),
ADD COLUMN IF NOT EXISTS user_1_phlock_added_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS user_2_has_in_phlock BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS user_2_phlock_position INT CHECK (user_2_phlock_position >= 1 AND user_2_phlock_position <= 5),
ADD COLUMN IF NOT EXISTS user_2_phlock_added_at TIMESTAMPTZ;

-- Migrate existing data: if is_phlock_member is true, we need to figure out who added whom
-- For now, we'll set it for user_1 (the original requester typically)
-- This may need manual correction for existing data
UPDATE friendships
SET user_1_has_in_phlock = is_phlock_member,
    user_1_phlock_position = position,
    user_1_phlock_added_at = last_swapped_at
WHERE is_phlock_member = true;

-- Create indexes for efficient phlock queries
CREATE INDEX IF NOT EXISTS idx_friendships_user1_phlock
ON friendships(user_id_1, user_1_has_in_phlock)
WHERE user_1_has_in_phlock = true;

CREATE INDEX IF NOT EXISTS idx_friendships_user2_phlock
ON friendships(user_id_2, user_2_has_in_phlock)
WHERE user_2_has_in_phlock = true;

-- Add comment explaining the schema
COMMENT ON COLUMN friendships.user_1_has_in_phlock IS 'True if user_id_1 has added user_id_2 to their phlock';
COMMENT ON COLUMN friendships.user_1_phlock_position IS 'Position (1-5) of user_id_2 in user_id_1 phlock';
COMMENT ON COLUMN friendships.user_2_has_in_phlock IS 'True if user_id_2 has added user_id_1 to their phlock';
COMMENT ON COLUMN friendships.user_2_phlock_position IS 'Position (1-5) of user_id_1 in user_id_2 phlock';
