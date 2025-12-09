-- Migration: Allow reading basic info of any daily song
-- Problem: When a user likes/comments on a daily song from someone not in their phlock
-- (e.g., via discover or search), we need to be able to read the share info to send
-- a notification to the share owner.
--
-- The existing policies only allow:
-- 1. Viewing shares you sent/received
-- 2. Viewing daily songs from your phlock members
--
-- But users can like/comment on ANY daily song they can see in their feed,
-- and we need to read that share's sender_id and track_name for notifications.

-- Add a policy that allows viewing any daily song
-- This is safe because daily songs are meant to be public/social content
DROP POLICY IF EXISTS "Users can view any daily song" ON shares;
CREATE POLICY "Users can view any daily song"
ON shares FOR SELECT
TO authenticated
USING (is_daily_song = true);

COMMENT ON POLICY "Users can view any daily song" ON shares IS
  'Daily songs are public social content - any authenticated user can view them for engagement features';
