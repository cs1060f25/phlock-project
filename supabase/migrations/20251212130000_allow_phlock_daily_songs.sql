-- Migration: Allow users to view daily songs from their phlock members
-- Problem: Daily songs are self-shares (sender_id = recipient_id), so other users
-- couldn't see them due to existing RLS policies.
-- Solution: Add a policy that allows viewing daily songs from phlock members.

-- Create a policy that allows viewing daily songs from users you have in your phlock
DROP POLICY IF EXISTS "Users can view daily songs from phlock members" ON shares;
CREATE POLICY "Users can view daily songs from phlock members"
ON shares FOR SELECT
USING (
  is_daily_song = true
  AND sender_id IN (
    -- Get all users that the current user has in their phlock
    SELECT following_id
    FROM follows
    WHERE follower_id = get_current_user_id()
    AND is_in_phlock = true
  )
);
