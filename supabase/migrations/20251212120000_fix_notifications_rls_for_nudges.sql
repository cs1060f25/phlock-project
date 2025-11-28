-- Align notifications RLS with Supabase Auth mapping and allow phlock nudges to upsert
-- Uses get_current_user_id() to map auth.uid() -> users.id and lets phlock members
-- update existing daily_nudge rows for aggregation.

-- Drop existing policies to replace them with auth-aware versions
DROP POLICY IF EXISTS "Users can view their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can insert notifications they trigger or receive" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their notifications" ON public.notifications;

-- Recipients can read their own notifications
CREATE POLICY "Users can view their notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (user_id = get_current_user_id());

-- Phlock members need to see existing daily nudges they sent so we can aggregate actor_ids
DROP POLICY IF EXISTS "Phlock members can view nudges they sent" ON public.notifications;
CREATE POLICY "Phlock members can view nudges they sent"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    type = 'daily_nudge'
    AND EXISTS (
      SELECT 1
      FROM follows f
      WHERE f.is_in_phlock = true
        AND (
          f.follower_id = get_current_user_id()
          AND f.following_id = user_id
        )
    )
  );

-- Users can create notifications they trigger or receive
CREATE POLICY "Users can insert notifications they trigger or receive"
  ON public.notifications
  FOR INSERT
  TO authenticated
  WITH CHECK (
    actor_user_id = get_current_user_id()
    OR user_id = get_current_user_id()
  );

-- Recipients can mark their notifications as read
CREATE POLICY "Users can update their notifications"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = get_current_user_id())
  WITH CHECK (user_id = get_current_user_id());

-- Phlock members can update daily nudges (to merge actor_ids for the same day)
DROP POLICY IF EXISTS "Phlock members can update daily nudges" ON public.notifications;
CREATE POLICY "Phlock members can update daily nudges"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    type = 'daily_nudge'
    AND EXISTS (
      SELECT 1
      FROM follows f
      WHERE f.is_in_phlock = true
        AND (
          f.follower_id = get_current_user_id()
          AND f.following_id = user_id
        )
    )
  )
  WITH CHECK (
    type = 'daily_nudge'
    AND EXISTS (
      SELECT 1
      FROM follows f
      WHERE f.is_in_phlock = true
        AND (
          f.follower_id = get_current_user_id()
          AND f.following_id = user_id
        )
    )
  );
