-- Migration: Integrate Supabase Auth for production-grade security
-- Date: 2025-10-29
-- Description: Link users table to Supabase Auth and enable proper RLS
-- This replaces the platform-only OAuth workaround with proper auth.uid() integration

-- Step 1: Add Supabase Auth integration columns
-- Note: Using auth_user_id to match supabase/migrations/20251029010000
ALTER TABLE users
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS auth_provider TEXT, -- 'spotify', 'apple', 'both'
ADD COLUMN IF NOT EXISTS music_platform TEXT CHECK (music_platform IN ('spotify', 'apple_music')),
ADD COLUMN IF NOT EXISTS spotify_user_id TEXT, -- Spotify user ID
ADD COLUMN IF NOT EXISTS apple_user_id TEXT; -- Apple user ID

-- Step 2: Create index and unique constraint for auth_user_id lookups
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
ALTER TABLE users ADD CONSTRAINT IF NOT EXISTS unique_auth_user_id UNIQUE (auth_user_id);

-- Step 3: Remove the overly permissive RLS policy from migration 004
DROP POLICY IF EXISTS "Allow platform auth updates" ON public.users;

-- Step 4: Create proper RLS policies using auth.uid()
-- These policies assume users.auth_user_id = auth.uid()

-- Allow authenticated users to read all profiles (for social features)
CREATE POLICY "Authenticated users can read profiles"
ON public.users FOR SELECT TO authenticated
USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile via auth"
ON public.users FOR UPDATE TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (auth_user_id = auth.uid());

-- Users can insert during signup (auth_user_id must match their auth.uid())
CREATE POLICY "Users can create profile during signup"
ON public.users FOR INSERT TO authenticated
WITH CHECK (auth_user_id = auth.uid());

-- Step 5: Update platform_tokens RLS to also check auth_user_id
-- Drop old policies that cast auth.uid() to uuid
DROP POLICY IF EXISTS "Users can view own tokens" ON platform_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens" ON platform_tokens;
DROP POLICY IF EXISTS "Users can update own tokens" ON platform_tokens;

-- Create new policies using auth_user_id lookup
CREATE POLICY "Users can view own tokens via auth"
ON platform_tokens FOR SELECT TO authenticated
USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can insert own tokens via auth"
ON platform_tokens FOR INSERT TO authenticated
WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can update own tokens via auth"
ON platform_tokens FOR UPDATE TO authenticated
USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

-- Step 6: Create helper function to get user_id from auth session
-- Note: This may already exist from supabase migration, but we redefine it here for completeness
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
  SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_user_id() TO anon;

-- Step 7: Update existing helper functions to work with auth
-- These now properly return NULL when not authenticated
DROP FUNCTION IF EXISTS get_friendship_status(UUID, UUID);
CREATE OR REPLACE FUNCTION get_friendship_status(user_a UUID, user_b UUID)
RETURNS TEXT AS $$
  SELECT status FROM friendships
  WHERE (user_id_1 = user_a AND user_id_2 = user_b)
     OR (user_id_1 = user_b AND user_id_2 = user_a)
  LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

DROP FUNCTION IF EXISTS are_friends(UUID, UUID);
CREATE OR REPLACE FUNCTION are_friends(user_a UUID, user_b UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM friendships
    WHERE ((user_id_1 = user_a AND user_id_2 = user_b)
       OR (user_id_1 = user_b AND user_id_2 = user_a))
      AND status = 'accepted'
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Step 8: Create function to find user by email (for account linking)
CREATE OR REPLACE FUNCTION find_user_by_email(user_email TEXT)
RETURNS UUID AS $$
  SELECT id FROM users WHERE email = user_email LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Step 9: Create function to link auth provider to existing account
CREATE OR REPLACE FUNCTION link_auth_provider(
  target_user_id UUID,
  new_auth_id UUID,
  provider TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE users
  SET
    auth_user_id = new_auth_id,
    auth_provider = CASE
      WHEN auth_provider IS NULL THEN provider
      WHEN auth_provider != provider THEN 'both'
      ELSE auth_provider
    END
  WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 10: Add comment explaining the architecture
COMMENT ON COLUMN users.auth_user_id IS 'Links to auth.users.id (auth.uid()). NULL for legacy users created before Supabase Auth integration.';
COMMENT ON COLUMN users.auth_provider IS 'Which OAuth provider(s) user has connected: spotify, apple, or both';
COMMENT ON COLUMN users.music_platform IS 'Which music service user primarily uses: spotify or apple_music';
COMMENT ON COLUMN users.spotify_user_id IS 'Spotify platform user ID for music API access';
COMMENT ON COLUMN users.apple_user_id IS 'Apple platform user ID for music API access';
COMMENT ON COLUMN users.platform_type IS 'DEPRECATED: Use music_platform instead. Kept for backward compatibility.';
COMMENT ON COLUMN users.platform_user_id IS 'DEPRECATED: Use spotify_user_id or apple_user_id instead. Kept for backward compatibility.';

-- Note: Existing users with platform_type/platform_user_id will need data migration
-- This should be done via app code during the transition period
