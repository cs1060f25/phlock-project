-- =====================================================
-- FIX RLS POLICIES FOR FRIENDS & FEED VISIBILITY
-- =====================================================
-- This ensures you can see:
-- 1. Your friends' profiles
-- 2. Friend-to-friend shares (for feed)
-- 3. All users (for discovery)
-- =====================================================

-- Drop existing policies that might be too restrictive
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can view friends' profiles" ON users;
DROP POLICY IF EXISTS "Users can view their own shares" ON shares;

-- =====================================================
-- USERS TABLE POLICIES
-- =====================================================

-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth_user_id = auth.uid());

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

-- Users can insert their own profile (during signup)
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth_user_id = auth.uid());

-- IMPORTANT: Users can view ALL other users' profiles (for discovery and friends)
CREATE POLICY "Users can view all profiles"
  ON users FOR SELECT
  USING (true);

-- =====================================================
-- SHARES TABLE POLICIES
-- =====================================================

-- Users can view shares they sent or received
CREATE POLICY "Users can view their own shares"
  ON shares FOR SELECT
  USING (
    sender_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR recipient_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- Users can view shares between their friends (for feed)
CREATE POLICY "Users can view friend activity"
  ON shares FOR SELECT
  USING (
    -- Get current user's ID
    EXISTS (
      SELECT 1 FROM users cu
      WHERE cu.auth_user_id = auth.uid()
      AND (
        -- Share involves friends
        sender_id IN (
          SELECT user_id_2 FROM friendships
          WHERE user_id_1 = cu.id AND status = 'accepted'
          UNION
          SELECT user_id_1 FROM friendships
          WHERE user_id_2 = cu.id AND status = 'accepted'
        )
        OR recipient_id IN (
          SELECT user_id_2 FROM friendships
          WHERE user_id_1 = cu.id AND status = 'accepted'
          UNION
          SELECT user_id_1 FROM friendships
          WHERE user_id_2 = cu.id AND status = 'accepted'
        )
      )
    )
  );

-- Users can create shares
DROP POLICY IF EXISTS "Users can create shares" ON shares;
CREATE POLICY "Users can create shares"
  ON shares FOR INSERT
  WITH CHECK (
    sender_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- Users can update shares (mark as played, saved, etc.)
DROP POLICY IF EXISTS "Users can update shares" ON shares;
CREATE POLICY "Users can update shares"
  ON shares FOR UPDATE
  USING (
    recipient_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- =====================================================
-- FRIENDSHIPS TABLE POLICIES
-- =====================================================

-- Drop and recreate friendship policies
DROP POLICY IF EXISTS "Users can view own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can create friendships" ON friendships;
DROP POLICY IF EXISTS "Users can update own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can delete own friendships" ON friendships;

-- Users can view their own friendships
CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  USING (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR user_id_2 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- Users can create friendships (send requests)
CREATE POLICY "Users can create friendships"
  ON friendships FOR INSERT
  WITH CHECK (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- Users can update friendships (accept/reject)
CREATE POLICY "Users can update own friendships"
  ON friendships FOR UPDATE
  USING (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR user_id_2 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- Users can delete friendships (unfriend)
CREATE POLICY "Users can delete own friendships"
  ON friendships FOR DELETE
  USING (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR user_id_2 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- =====================================================
-- VERIFY SETUP
-- =====================================================

DO $$
DECLARE
  my_user_id UUID;
  friend_count INTEGER;
  share_count INTEGER;
BEGIN
  -- Find current user
  SELECT id INTO my_user_id
  FROM users
  WHERE auth_user_id = '45DB2427-9B99-49BF-A334-895EC91B038C'::uuid;

  IF my_user_id IS NOT NULL THEN
    -- Count friends
    SELECT COUNT(*) INTO friend_count
    FROM friendships
    WHERE (user_id_1 = my_user_id OR user_id_2 = my_user_id)
    AND status = 'accepted';

    -- Count shares
    SELECT COUNT(*) INTO share_count
    FROM shares
    WHERE sender_id = my_user_id OR recipient_id = my_user_id;

    RAISE NOTICE '✅ RLS Policies Updated!';
    RAISE NOTICE '  User: %', my_user_id;
    RAISE NOTICE '  Friends: %', friend_count;
    RAISE NOTICE '  Shares: %', share_count;
  ELSE
    RAISE NOTICE '⚠️ Could not find user with auth_user_id';
  END IF;
END $$;
