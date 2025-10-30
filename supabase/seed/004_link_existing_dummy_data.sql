-- =====================================================
-- LINK EXISTING DUMMY DATA TO YOUR ACCOUNT
-- =====================================================
-- This finds existing dummy users and creates
-- friendships and shares for YOUR account
-- =====================================================

DO $$
DECLARE
  -- Your user ID
  my_user_id UUID;

  -- Friend user IDs (from existing users)
  emma_id UUID;
  marcus_id UUID;
  sofia_id UUID;
  tyler_id UUID;
  maya_id UUID;
  alex_id UUID;
  jordan_id UUID;
  taylor_id UUID;
  ryan_id UUID;
  lisa_id UUID;
  kai_id UUID;
  zara_id UUID;
  devon_id UUID;

BEGIN
  -- Find YOUR user by auth_user_id
  SELECT id INTO my_user_id
  FROM users
  WHERE auth_user_id = '45DB2427-9B99-49BF-A334-895EC91B038C'::uuid
  LIMIT 1;

  IF my_user_id IS NULL THEN
    RAISE EXCEPTION 'Could not find user with auth_user_id 45DB2427-9B99-49BF-A334-895EC91B038C';
  END IF;

  -- Find existing dummy users by email
  SELECT id INTO emma_id FROM users WHERE email = 'emma.rodriguez@example.com';
  SELECT id INTO marcus_id FROM users WHERE email = 'marcus.chen@example.com';
  SELECT id INTO sofia_id FROM users WHERE email = 'sofia.martinez@example.com';
  SELECT id INTO tyler_id FROM users WHERE email = 'tyler.wash@example.com';
  SELECT id INTO maya_id FROM users WHERE email = 'maya.patel@example.com';
  SELECT id INTO alex_id FROM users WHERE email = 'alex.kim@example.com';
  SELECT id INTO jordan_id FROM users WHERE email = 'jordan.lee@example.com';
  SELECT id INTO taylor_id FROM users WHERE email = 'taylor.brooks@example.com';
  SELECT id INTO ryan_id FROM users WHERE email = 'ryan.cooper@example.com';
  SELECT id INTO lisa_id FROM users WHERE email = 'lisa.nguyen@example.com';
  SELECT id INTO kai_id FROM users WHERE email = 'kai.anderson@example.com';
  SELECT id INTO zara_id FROM users WHERE email = 'zara.johnson@example.com';
  SELECT id INTO devon_id FROM users WHERE email = 'devon.smith@example.com';

  RAISE NOTICE 'Linking dummy data for user: %', my_user_id;
  RAISE NOTICE 'Found dummy users: Emma=%, Marcus=%, Sofia=%', emma_id, marcus_id, sofia_id;

  -- Delete any existing friendships/shares for clean slate
  DELETE FROM shares WHERE sender_id = my_user_id OR recipient_id = my_user_id;
  DELETE FROM friendships WHERE user_id_1 = my_user_id OR user_id_2 = my_user_id;

  -- =====================================================
  -- CREATE FRIENDSHIPS
  -- =====================================================

  INSERT INTO friendships (user_id_1, user_id_2, status, created_at) VALUES
  (my_user_id, emma_id, 'accepted', NOW() - INTERVAL '44 days'),
  (my_user_id, marcus_id, 'accepted', NOW() - INTERVAL '37 days'),
  (sofia_id, my_user_id, 'accepted', NOW() - INTERVAL '51 days'),
  (my_user_id, tyler_id, 'accepted', NOW() - INTERVAL '28 days'),
  (maya_id, my_user_id, 'accepted', NOW() - INTERVAL '66 days'),
  (my_user_id, alex_id, 'accepted', NOW() - INTERVAL '40 days'),
  (jordan_id, my_user_id, 'accepted', NOW() - INTERVAL '18 days'),
  (my_user_id, taylor_id, 'accepted', NOW() - INTERVAL '54 days');

  -- Pending requests
  INSERT INTO friendships (user_id_1, user_id_2, status, created_at) VALUES
  (ryan_id, my_user_id, 'pending', NOW() - INTERVAL '2 days'),
  (lisa_id, my_user_id, 'pending', NOW() - INTERVAL '4 days')
  ON CONFLICT DO NOTHING;

  -- =====================================================
  -- CREATE SHARES
  -- =====================================================

  -- YOU RECEIVED
  INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  (emma_id, my_user_id, '3n3Ppam7vgaVa1iaRUc9Lp', 'Mr. Brightside', 'The Killers', 'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d', 'This song never gets old! 🎉', 'sent', NOW() - INTERVAL '2 hours'),
  (marcus_id, my_user_id, '0VjIjW4GlUZAMYd2vXMi3b', 'Blinding Lights', 'The Weeknd', 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36', 'Perfect driving song 🚗💨', 'sent', NOW() - INTERVAL '5 hours'),
  (sofia_id, my_user_id, '6habFhsOp2NvshLv26DqMb', 'Therefore I Am', 'Billie Eilish', 'https://i.scdn.co/image/ab67616d0000b273938eb6769c6c123a3cbebfae', 'Billie is just *chef''s kiss* 💋', 'sent', NOW() - INTERVAL '1 day'),
  (tyler_id, my_user_id, '7qiZfU4dY1lWllzX7mPBI', 'Shape of You', 'Ed Sheeran', 'https://i.scdn.co/image/ab67616d0000b273ba5db46f4b838ef6027e6f96', 'Found this gem 😂', 'played', NOW() - INTERVAL '1 day'),
  (maya_id, my_user_id, '3qiyyUfYe7CRYLucrPmulD', 'Someone Like You', 'Adele', 'https://i.scdn.co/image/ab67616d0000b2732118bf9b198b05a95ded6300', 'Crying to this 😭', 'saved', NOW() - INTERVAL '2 days'),
  (alex_id, my_user_id, '0DiWol3AO6WpXZgp0goxAV', 'One Dance', 'Drake ft. Wizkid', 'https://i.scdn.co/image/ab67616d0000b273f46b9d202509a8f7384b90de', 'Summer vibes ☀️', 'sent', NOW() - INTERVAL '3 days'),
  (jordan_id, my_user_id, '3DamFFqW32WihKkTVlwTYQ', 'Levitating', 'Dua Lipa', 'https://i.scdn.co/image/ab67616d0000b273be841ba4bc24340152e3a79a', 'On repeat! 🔁', 'sent', NOW() - INTERVAL '4 days'),
  (taylor_id, my_user_id, '0sf6QqfHFJYhYQDSEYR1cK', 'Watermelon Sugar', 'Harry Styles', 'https://i.scdn.co/image/ab67616d0000b2733c8896f56a1e09b234ce7e96', 'Harry ✨', 'sent', NOW() - INTERVAL '5 days');

  -- YOU SENT
  INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  (my_user_id, emma_id, '5Z01UMMf7V1o0MzF86s6WJ', 'Starboy', 'The Weeknd ft. Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2734718e2b124f79258be7bc452', 'Vibe with this!', 'sent', NOW() - INTERVAL '6 hours'),
  (my_user_id, marcus_id, '2takcwOaAZWiXQijPHIx7B', 'Time', 'Pink Floyd', 'https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe', 'Classic', 'sent', NOW() - INTERVAL '2 days'),
  (my_user_id, sofia_id, '4LRPiXqCikLlN15c3yImP7', 'As It Was', 'Harry Styles', 'https://i.scdn.co/image/ab67616d0000b2732e8ed79e177ff6011076f5f0', 'New Harry! 🎵', 'sent', NOW() - INTERVAL '3 days');

  -- FRIEND-TO-FRIEND (for feed)
  INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  (emma_id, marcus_id, '4cOdK2wGLETKBW3PvgPWqT', 'Sunflower', 'Post Malone', 'https://i.scdn.co/image/ab67616d0000b273e2e352d89826aef6dbd5ff8f', 'Spider-verse 🕷️', 'sent', NOW() - INTERVAL '8 hours'),
  (marcus_id, sofia_id, '7ytR5pFWmSjzHJIeQkgog4', 'HUMBLE.', 'Kendrick Lamar', 'https://i.scdn.co/image/ab67616d0000b2738b52c6b9bc4e43d873869699', 'Kendrick 🔥', 'played', NOW() - INTERVAL '12 hours'),
  (sofia_id, tyler_id, '3WMj8moIAXJhHsyLaqIIHI', 'Peaches', 'Justin Bieber', 'https://i.scdn.co/image/ab67616d0000b273e6ca9cc11596dc34e8ac472d', 'Smooth vibes', 'sent', NOW() - INTERVAL '1 day'),
  (tyler_id, alex_id, '6DCZcSspjsKoFjzjrWoCdn', 'God''s Plan', 'Drake', 'https://i.scdn.co/image/ab67616d0000b273f907de96b9a4fbc04accc0d5', 'This beat 🔥', 'sent', NOW() - INTERVAL '2 days');

  RAISE NOTICE '✅ Successfully linked dummy data to user %', my_user_id;
  RAISE NOTICE '  - 8 friends added';
  RAISE NOTICE '  - 2 pending requests';
  RAISE NOTICE '  - 8 shares received';
  RAISE NOTICE '  - 3 shares sent';
  RAISE NOTICE '  - 4 friend-to-friend shares';

END $$;
