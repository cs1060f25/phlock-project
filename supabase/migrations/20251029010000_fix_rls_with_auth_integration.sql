-- =====================================================
-- FIX RLS POLICIES WITH PROPER AUTH INTEGRATION
-- =====================================================
-- This migration properly integrates Supabase Auth with the custom users table
-- by linking auth.users to the custom users table via auth_user_id column.
--
-- Created: 2025-10-29
-- Purpose: Implement proper long-term RLS solution for phlock tables
-- =====================================================

-- Step 1: Add auth_user_id column to users table
-- This links custom users to Supabase Auth users
ALTER TABLE users
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);

-- Create unique constraint to ensure one-to-one mapping (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_auth_user_id') THEN
    ALTER TABLE users ADD CONSTRAINT unique_auth_user_id UNIQUE (auth_user_id);
  END IF;
END $$;

-- Step 2: Create helper function to get user_id from auth.uid()
-- This function looks up the custom user ID based on the Supabase Auth user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$;

-- Step 3: Drop old RLS policies that don't work
DROP POLICY IF EXISTS "Users can view their own phlocks" ON phlocks;
DROP POLICY IF EXISTS "Users can create their own phlocks" ON phlocks;
DROP POLICY IF EXISTS "Users can update their own phlocks" ON phlocks;
DROP POLICY IF EXISTS "Users can view nodes in their phlocks" ON phlock_nodes;
DROP POLICY IF EXISTS "System can create nodes" ON phlock_nodes;
DROP POLICY IF EXISTS "Users can view their own shares" ON shares;
DROP POLICY IF EXISTS "Users can view their sent shares" ON shares;
DROP POLICY IF EXISTS "Users can view their received shares" ON shares;
DROP POLICY IF EXISTS "Users can create shares" ON shares;
DROP POLICY IF EXISTS "Users can update their shares" ON shares;
DROP POLICY IF EXISTS "Users can view their engagements" ON engagements;
DROP POLICY IF EXISTS "Users can create engagements" ON engagements;
DROP POLICY IF EXISTS "Users can create their engagements" ON engagements;

-- Step 4: Re-enable RLS (in case it was disabled)
ALTER TABLE phlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE phlock_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagements ENABLE ROW LEVEL SECURITY;

-- Step 5: Create new RLS policies using the helper function

-- PHLOCKS TABLE POLICIES
CREATE POLICY "Users can view their own phlocks"
ON phlocks FOR SELECT
USING (created_by = get_current_user_id());

CREATE POLICY "Users can create their own phlocks"
ON phlocks FOR INSERT
WITH CHECK (created_by = get_current_user_id());

CREATE POLICY "Users can update their own phlocks"
ON phlocks FOR UPDATE
USING (created_by = get_current_user_id());

-- PHLOCK_NODES TABLE POLICIES
-- Users can view nodes in phlocks they created
CREATE POLICY "Users can view nodes in their phlocks"
ON phlock_nodes FOR SELECT
USING (
  phlock_id IN (
    SELECT id FROM phlocks WHERE created_by = get_current_user_id()
  )
);

CREATE POLICY "System can create nodes"
ON phlock_nodes FOR INSERT
WITH CHECK (true); -- Allow system to create nodes for any phlock

-- SHARES TABLE POLICIES
CREATE POLICY "Users can view their sent shares"
ON shares FOR SELECT
USING (sender_id = get_current_user_id());

CREATE POLICY "Users can view their received shares"
ON shares FOR SELECT
USING (recipient_id = get_current_user_id());

CREATE POLICY "Users can create shares"
ON shares FOR INSERT
WITH CHECK (sender_id = get_current_user_id());

CREATE POLICY "Users can update their shares"
ON shares FOR UPDATE
USING (
  sender_id = get_current_user_id() OR
  recipient_id = get_current_user_id()
);

-- ENGAGEMENTS TABLE POLICIES
CREATE POLICY "Users can view their engagements"
ON engagements FOR SELECT
USING (user_id = get_current_user_id());

CREATE POLICY "Users can create their engagements"
ON engagements FOR INSERT
WITH CHECK (user_id = get_current_user_id());

-- Step 6: Grant execute permission on helper function to authenticated users
GRANT EXECUTE ON FUNCTION get_current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_id() TO anon;

-- =====================================================
-- VERIFICATION QUERIES (run these manually to test)
-- =====================================================
-- Check if auth_user_id column was added:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'auth_user_id';
--
-- Check if RLS is enabled:
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('phlocks', 'phlock_nodes', 'shares', 'engagements');
--
-- List all policies:
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE tablename IN ('phlocks', 'phlock_nodes', 'shares', 'engagements');
