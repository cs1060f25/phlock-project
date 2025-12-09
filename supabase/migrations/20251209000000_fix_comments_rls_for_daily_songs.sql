-- Migration: Fix share_comments RLS policies to allow commenting on daily songs
-- The previous policy only allowed commenting on shares where user is sender/recipient
-- This update allows commenting on any daily song (is_daily_song = true)

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view comments on their shares" ON share_comments;
DROP POLICY IF EXISTS "Users can comment on their shares" ON share_comments;

-- Recreate SELECT policy to include daily songs
CREATE POLICY "Users can view comments on shares"
  ON share_comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (
        shares.sender_id = auth.uid()
        OR shares.recipient_id = auth.uid()
        OR shares.is_daily_song = true
      )
    )
  );

-- Recreate INSERT policy to allow commenting on daily songs
CREATE POLICY "Users can comment on shares"
  ON share_comments
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (
        shares.sender_id = auth.uid()
        OR shares.recipient_id = auth.uid()
        OR shares.is_daily_song = true
      )
    )
  );

COMMENT ON POLICY "Users can view comments on shares" ON share_comments IS
  'Users can view comments on shares they are part of OR any daily song';
COMMENT ON POLICY "Users can comment on shares" ON share_comments IS
  'Users can comment on shares they are part of OR any daily song';
