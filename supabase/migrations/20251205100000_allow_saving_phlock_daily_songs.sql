-- Migration: Allow users to mark daily songs from phlock members as saved
-- Problem: When User B saves User A's daily song, the UPDATE fails because:
--   - Daily songs are self-shares (sender_id = recipient_id = User A)
--   - Existing RLS policy only allows updates if you are sender OR recipient
--   - User B is neither, so the update is blocked
-- Solution: Add an UPDATE policy for daily songs from phlock members

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can save daily songs from phlock members" ON shares;

-- Create policy that allows updating saved_at and status on daily songs from phlock members
CREATE POLICY "Users can save daily songs from phlock members"
ON shares FOR UPDATE
USING (
  -- Can update daily songs from users in your phlock
  is_daily_song = true
  AND sender_id IN (
    SELECT following_id
    FROM follows
    WHERE follower_id = get_current_user_id()
    AND is_in_phlock = true
  )
)
WITH CHECK (
  -- Same condition for the updated row
  is_daily_song = true
  AND sender_id IN (
    SELECT following_id
    FROM follows
    WHERE follower_id = get_current_user_id()
    AND is_in_phlock = true
  )
);
