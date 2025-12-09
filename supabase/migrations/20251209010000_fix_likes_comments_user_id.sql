-- Migration: Fix share_likes and share_comments RLS to use get_current_user_id()
--
-- Problem: The RLS policies use auth.uid() directly for user_id checks, but:
-- - share_likes.user_id references users.id (not auth.users.id)
-- - share_comments.user_id references users.id (not auth.users.id)
-- - auth.uid() returns auth.users.id, not users.id
--
-- Solution: Use get_current_user_id() which maps auth.uid() -> users.id

-- Ensure get_current_user_id() function exists
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID
LANGUAGE SQL
STABLE
SECURITY DEFINER
AS $$
  SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- ============================================
-- Fix share_likes RLS policies
-- ============================================

DROP POLICY IF EXISTS "Users can view likes on shares" ON share_likes;
DROP POLICY IF EXISTS "Users can like visible shares" ON share_likes;
DROP POLICY IF EXISTS "Users can unlike their own likes" ON share_likes;

-- Users can view likes on shares they're part of or any daily song
CREATE POLICY "Users can view likes on shares"
    ON share_likes
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM shares s
            WHERE s.id = share_likes.share_id
            AND (
                s.sender_id = get_current_user_id()
                OR s.recipient_id = get_current_user_id()
                OR s.is_daily_song = true
            )
        )
    );

-- Users can like any daily song or shares they're part of
CREATE POLICY "Users can like visible shares"
    ON share_likes
    FOR INSERT
    WITH CHECK (
        user_id = get_current_user_id()
        AND EXISTS (
            SELECT 1 FROM shares s
            WHERE s.id = share_likes.share_id
            AND (
                s.sender_id = get_current_user_id()
                OR s.recipient_id = get_current_user_id()
                OR s.is_daily_song = true
            )
        )
    );

-- Users can only delete their own likes
CREATE POLICY "Users can unlike their own likes"
    ON share_likes
    FOR DELETE
    USING (user_id = get_current_user_id());

-- ============================================
-- Fix share_comments RLS policies
-- ============================================

DROP POLICY IF EXISTS "Users can view comments on shares" ON share_comments;
DROP POLICY IF EXISTS "Users can comment on shares" ON share_comments;
DROP POLICY IF EXISTS "Users can update own comments" ON share_comments;
DROP POLICY IF EXISTS "Users can delete own comments" ON share_comments;

-- Users can view comments on shares they're part of or any daily song
CREATE POLICY "Users can view comments on shares"
  ON share_comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (
        shares.sender_id = get_current_user_id()
        OR shares.recipient_id = get_current_user_id()
        OR shares.is_daily_song = true
      )
    )
  );

-- Users can comment on shares they're part of or any daily song
CREATE POLICY "Users can comment on shares"
  ON share_comments
  FOR INSERT
  WITH CHECK (
    user_id = get_current_user_id()
    AND EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (
        shares.sender_id = get_current_user_id()
        OR shares.recipient_id = get_current_user_id()
        OR shares.is_daily_song = true
      )
    )
  );

-- Users can update their own comments
CREATE POLICY "Users can update own comments"
  ON share_comments
  FOR UPDATE
  USING (user_id = get_current_user_id())
  WITH CHECK (user_id = get_current_user_id());

-- Users can delete their own comments
CREATE POLICY "Users can delete own comments"
  ON share_comments
  FOR DELETE
  USING (user_id = get_current_user_id());

COMMENT ON POLICY "Users can view likes on shares" ON share_likes IS
  'Users can view likes on shares they participate in or any daily song';
COMMENT ON POLICY "Users can like visible shares" ON share_likes IS
  'Users can like shares they participate in or any daily song (user_id must match their users.id)';
COMMENT ON POLICY "Users can view comments on shares" ON share_comments IS
  'Users can view comments on shares they participate in or any daily song';
COMMENT ON POLICY "Users can comment on shares" ON share_comments IS
  'Users can comment on shares they participate in or any daily song (user_id must match their users.id)';
