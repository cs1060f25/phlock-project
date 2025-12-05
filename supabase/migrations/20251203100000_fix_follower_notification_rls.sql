-- Fix duplicate follow notifications by allowing actors to view/update notifications they created
--
-- Problem: When a user follows someone, a notification is created with:
--   - user_id = recipient (person being followed)
--   - actor_user_id = follower
--
-- The existing RLS policies only let recipients (user_id) view/update notifications.
-- When the follower tries to check for existing notifications to upsert, the query
-- returns empty due to RLS, causing duplicate notifications on re-follow.
--
-- Solution: Add policies allowing actors to view and update follow-type notifications
-- they created, similar to the existing daily_nudge actor policies.

-- Allow actors to view follow notifications they created (for upsert duplicate check)
CREATE POLICY "Actors can view follow notifications they created"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (
    type IN ('new_follower', 'follow_request_received')
    AND actor_user_id = get_current_user_id()
  );

-- Allow actors to update follow notifications they created (for timestamp refresh on re-follow)
CREATE POLICY "Actors can update follow notifications they created"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING (
    type IN ('new_follower', 'follow_request_received')
    AND actor_user_id = get_current_user_id()
  )
  WITH CHECK (
    type IN ('new_follower', 'follow_request_received')
    AND actor_user_id = get_current_user_id()
  );

-- Clean up existing duplicate notifications (keep only the most recent per user/actor/type combo)
-- This uses a CTE to identify duplicates and delete all but the newest one
DELETE FROM public.notifications
WHERE id IN (
  SELECT id FROM (
    SELECT
      id,
      ROW_NUMBER() OVER (
        PARTITION BY user_id, actor_user_id, type
        ORDER BY created_at DESC
      ) as rn
    FROM public.notifications
    WHERE type IN ('new_follower', 'follow_request_received')
      AND actor_user_id IS NOT NULL
  ) ranked
  WHERE rn > 1
);
