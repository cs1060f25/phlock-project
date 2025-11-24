-- Re-align scheduled_swaps RLS with users.auth_user_id so app inserts succeed
-- Run in Supabase SQL editor or psql

BEGIN;

-- Drop old policies that compare auth.uid() directly to user_id (user_id references users.id)
DROP POLICY IF EXISTS "Users can view their own scheduled swaps" ON scheduled_swaps;
DROP POLICY IF EXISTS "Users can create their own scheduled swaps" ON scheduled_swaps;
DROP POLICY IF EXISTS "Users can update their own scheduled swaps" ON scheduled_swaps;

-- Helper condition: current auth user owns the scheduled_swaps row
CREATE POLICY "Users can view their own scheduled swaps"
  ON scheduled_swaps FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = scheduled_swaps.user_id
        AND u.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create their own scheduled swaps"
  ON scheduled_swaps FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = scheduled_swaps.user_id
        AND u.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own scheduled swaps"
  ON scheduled_swaps FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users u
      WHERE u.id = scheduled_swaps.user_id
        AND u.auth_user_id = auth.uid()
    )
  );

COMMIT;
