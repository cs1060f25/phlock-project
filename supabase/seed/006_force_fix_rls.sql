-- =====================================================
-- FORCE FIX RLS POLICIES (IDEMPOTENT)
-- =====================================================
-- Drops and recreates all policies cleanly
-- =====================================================

-- =====================================================
-- USERS TABLE POLICIES
-- =====================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can view friends' profiles" ON users;
DROP POLICY IF EXISTS "Users can view all profiles" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;

-- Recreate policies
CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth_user_id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth_user_id = auth.uid())
  WITH CHECK (auth_user_id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON users FOR INSERT
  WITH CHECK (auth_user_id = auth.uid());

CREATE POLICY "Users can view all profiles"
  ON users FOR SELECT
  USING (true);

-- =====================================================
-- SHARES TABLE POLICIES
-- =====================================================

DROP POLICY IF EXISTS "Users can view their own shares" ON shares;
DROP POLICY IF EXISTS "Users can view friend activity" ON shares;
DROP POLICY IF EXISTS "Users can create shares" ON shares;
DROP POLICY IF EXISTS "Users can update shares" ON shares;

CREATE POLICY "Users can view their own shares"
  ON shares FOR SELECT
  USING (
    sender_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR recipient_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "Users can view friend activity"
  ON shares FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users cu
      WHERE cu.auth_user_id = auth.uid()
      AND (
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

CREATE POLICY "Users can create shares"
  ON shares FOR INSERT
  WITH CHECK (
    sender_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "Users can update shares"
  ON shares FOR UPDATE
  USING (
    recipient_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

-- =====================================================
-- FRIENDSHIPS TABLE POLICIES
-- =====================================================

DROP POLICY IF EXISTS "Users can view own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can create friendships" ON friendships;
DROP POLICY IF EXISTS "Users can update own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can delete own friendships" ON friendships;

CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  USING (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR user_id_2 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "Users can create friendships"
  ON friendships FOR INSERT
  WITH CHECK (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "Users can update own friendships"
  ON friendships FOR UPDATE
  USING (
    user_id_1 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
    OR user_id_2 IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
  );

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
  SELECT id INTO my_user_id
  FROM users
  WHERE auth_user_id = '45DB2427-9B99-49BF-A334-895EC91B038C'::uuid;

  IF my_user_id IS NOT NULL THEN
    SELECT COUNT(*) INTO friend_count
    FROM friendships
    WHERE (user_id_1 = my_user_id OR user_id_2 = my_user_id)
    AND status = 'accepted';

    SELECT COUNT(*) INTO share_count
    FROM shares
    WHERE sender_id = my_user_id OR recipient_id = my_user_id;

    RAISE NOTICE '✅ RLS Policies Updated!';
    RAISE NOTICE '  User: %', my_user_id;
    RAISE NOTICE '  Friends: %', friend_count;
    RAISE NOTICE '  Shares: %', share_count;
  ELSE
    RAISE NOTICE '⚠️ Could not find user';
  END IF;
END $$;
