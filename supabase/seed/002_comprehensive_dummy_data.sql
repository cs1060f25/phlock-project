-- =====================================================
-- COMPREHENSIVE DUMMY DATA FOR PHLOCK APP
-- =====================================================
-- This creates a realistic social music sharing experience
-- with friends, shares, phlocks, and feed activity
-- =====================================================

-- Get the current authenticated user (YOU)
-- We'll create data relative to you
DO $$
DECLARE
  current_user_id UUID;
  current_user_email TEXT;

  -- Friend user IDs
  emma_id UUID := uuid_generate_v4();
  marcus_id UUID := uuid_generate_v4();
  sofia_id UUID := uuid_generate_v4();
  tyler_id UUID := uuid_generate_v4();
  maya_id UUID := uuid_generate_v4();
  alex_id UUID := uuid_generate_v4();
  jordan_id UUID := uuid_generate_v4();
  taylor_id UUID := uuid_generate_v4();

  -- Pending friend request IDs
  ryan_id UUID := uuid_generate_v4();
  lisa_id UUID := uuid_generate_v4();

  -- People to discover IDs
  kai_id UUID := uuid_generate_v4();
  zara_id UUID := uuid_generate_v4();
  devon_id UUID := uuid_generate_v4();

  -- Share IDs
  share1_id UUID := uuid_generate_v4();
  share2_id UUID := uuid_generate_v4();
  share3_id UUID := uuid_generate_v4();
  share4_id UUID := uuid_generate_v4();
  share5_id UUID := uuid_generate_v4();
  share6_id UUID := uuid_generate_v4();
  share7_id UUID := uuid_generate_v4();
  share8_id UUID := uuid_generate_v4();

BEGIN
  -- Find the most recent user (you!)
  SELECT id, email INTO current_user_id, current_user_email
  FROM users
  ORDER BY created_at DESC
  LIMIT 1;

  RAISE NOTICE 'Creating dummy data for user: % (%)', current_user_id, current_user_email;

  -- =====================================================
  -- CREATE DUMMY USERS
  -- =====================================================

  -- Your close friends (accepted friendships)
  INSERT INTO users (id, display_name, email, bio, profile_photo_url, created_at) VALUES
  (
    emma_id,
    'Emma Rodriguez',
    'emma.rodriguez@example.com',
    'indie pop enthusiast 🎸 | finding gems in the underground',
    'https://i.pravatar.cc/150?img=5',
    NOW() - INTERVAL '45 days'
  ),
  (
    marcus_id,
    'Marcus Chen',
    'marcus.chen@example.com',
    'jazz + hip hop = my vibe | always searching for that perfect beat',
    'https://i.pravatar.cc/150?img=12',
    NOW() - INTERVAL '38 days'
  ),
  (
    sofia_id,
    'Sofia Martinez',
    'sofia.martinez@example.com',
    'R&B soul | curator of late night vibes 🌙',
    'https://i.pravatar.cc/150?img=9',
    NOW() - INTERVAL '52 days'
  ),
  (
    tyler_id,
    'Tyler Washington',
    'tyler.wash@example.com',
    'producer | living in the studio | trap & electronic fusion',
    'https://i.pravatar.cc/150?img=33',
    NOW() - INTERVAL '29 days'
  ),
  (
    maya_id,
    'Maya Patel',
    'maya.patel@example.com',
    'classical meets modern | violin player | experimental sounds',
    'https://i.pravatar.cc/150?img=26',
    NOW() - INTERVAL '67 days'
  ),
  (
    alex_id,
    'Alex Kim',
    'alex.kim@example.com',
    'indie rock all day | concert photographer | live music is life',
    'https://i.pravatar.cc/150?img=14',
    NOW() - INTERVAL '41 days'
  ),
  (
    jordan_id,
    'Jordan Lee',
    'jordan.lee@example.com',
    'lo-fi beats to study/relax to | bedroom producer',
    'https://i.pravatar.cc/150?img=23',
    NOW() - INTERVAL '19 days'
  ),
  (
    taylor_id,
    'Taylor Brooks',
    'taylor.brooks@example.com',
    'alternative everything | playlist curator | music = therapy',
    'https://i.pravatar.cc/150?img=31',
    NOW() - INTERVAL '55 days'
  );

  -- People who sent you friend requests (pending)
  INSERT INTO users (id, display_name, email, bio, profile_photo_url, created_at) VALUES
  (
    ryan_id,
    'Ryan Cooper',
    'ryan.cooper@example.com',
    'EDM festival junkie | sharing the energy ⚡',
    'https://i.pravatar.cc/150?img=17',
    NOW() - INTERVAL '3 days'
  ),
  (
    lisa_id,
    'Lisa Nguyen',
    'lisa.nguyen@example.com',
    'K-pop & J-pop obsessed | spreading the love',
    'https://i.pravatar.cc/150?img=20',
    NOW() - INTERVAL '5 days'
  );

  -- People to discover (not friends yet)
  INSERT INTO users (id, display_name, email, bio, profile_photo_url, created_at) VALUES
  (
    kai_id,
    'Kai Anderson',
    'kai.anderson@example.com',
    'ambient soundscapes | meditation music creator',
    'https://i.pravatar.cc/150?img=8',
    NOW() - INTERVAL '12 days'
  ),
  (
    zara_id,
    'Zara Johnson',
    'zara.johnson@example.com',
    'afrobeats & world music | cultural curator',
    'https://i.pravatar.cc/150?img=27',
    NOW() - INTERVAL '22 days'
  ),
  (
    devon_id,
    'Devon Smith',
    'devon.smith@example.com',
    'punk rock forever | skate or die',
    'https://i.pravatar.cc/150?img=15',
    NOW() - INTERVAL '8 days'
  );

  -- =====================================================
  -- CREATE FRIENDSHIPS
  -- =====================================================

  -- Accepted friendships (your friends)
  INSERT INTO friendships (user_id_1, user_id_2, status, created_at) VALUES
  (current_user_id, emma_id, 'accepted', NOW() - INTERVAL '44 days'),
  (current_user_id, marcus_id, 'accepted', NOW() - INTERVAL '37 days'),
  (sofia_id, current_user_id, 'accepted', NOW() - INTERVAL '51 days'),
  (current_user_id, tyler_id, 'accepted', NOW() - INTERVAL '28 days'),
  (maya_id, current_user_id, 'accepted', NOW() - INTERVAL '66 days'),
  (current_user_id, alex_id, 'accepted', NOW() - INTERVAL '40 days'),
  (jordan_id, current_user_id, 'accepted', NOW() - INTERVAL '18 days'),
  (current_user_id, taylor_id, 'accepted', NOW() - INTERVAL '54 days');

  -- Pending friend requests (people waiting for you to accept)
  INSERT INTO friendships (user_id_1, user_id_2, status, created_at) VALUES
  (ryan_id, current_user_id, 'pending', NOW() - INTERVAL '2 days'),
  (lisa_id, current_user_id, 'pending', NOW() - INTERVAL '4 days');

  -- Friends are also friends with each other (realistic social network)
  INSERT INTO friendships (user_id_1, user_id_2, status, created_at) VALUES
  (emma_id, marcus_id, 'accepted', NOW() - INTERVAL '50 days'),
  (sofia_id, maya_id, 'accepted', NOW() - INTERVAL '60 days'),
  (tyler_id, alex_id, 'accepted', NOW() - INTERVAL '35 days'),
  (jordan_id, taylor_id, 'accepted', NOW() - INTERVAL '25 days');

  -- =====================================================
  -- CREATE SHARES (Music sent between users)
  -- =====================================================

  -- YOU RECEIVED from friends (feed activity)
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  -- From Emma (2 hours ago)
  (
    uuid_generate_v4(),
    emma_id,
    current_user_id,
    '3n3Ppam7vgaVa1iaRUc9Lp',
    'Mr. Brightside',
    'The Killers',
    'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d',
    'This song never gets old! Heard it at a party last night 🎉',
    'sent',
    NOW() - INTERVAL '2 hours'
  ),
  -- From Marcus (5 hours ago)
  (
    uuid_generate_v4(),
    marcus_id,
    current_user_id,
    '0VjIjW4GlUZAMYd2vXMi3b',
    'Blinding Lights',
    'The Weeknd',
    'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
    'Perfect driving song 🚗💨',
    'sent',
    NOW() - INTERVAL '5 hours'
  ),
  -- From Sofia (yesterday)
  (
    uuid_generate_v4(),
    sofia_id,
    current_user_id,
    '6habFhsOp2NvshLv26DqMb',
    'Therefore I Am',
    'Billie Eilish',
    'https://i.scdn.co/image/ab67616d0000b273938eb6769c6c123a3cbebfae',
    'Billie is just *chef''s kiss* 💋',
    'sent',
    NOW() - INTERVAL '1 day'
  ),
  -- From Tyler (yesterday)
  (
    uuid_generate_v4(),
    tyler_id,
    current_user_id,
    '7qiZfU4dY1lWllzX7mPBI',
    'Shape of You',
    'Ed Sheeran',
    'https://i.scdn.co/image/ab67616d0000b273ba5db46f4b838ef6027e6f96',
    'Found this hidden gem 😂 jk but it slaps',
    'played',
    NOW() - INTERVAL '1 day'
  ),
  -- From Maya (2 days ago)
  (
    uuid_generate_v4(),
    maya_id,
    current_user_id,
    '3qiyyUfYe7CRYLucrPmulD',
    'Someone Like You',
    'Adele',
    'https://i.scdn.co/image/ab67616d0000b2732118bf9b198b05a95ded6300',
    'Crying in the club to this one 😭',
    'saved',
    NOW() - INTERVAL '2 days'
  ),
  -- From Alex (3 days ago)
  (
    uuid_generate_v4(),
    alex_id,
    current_user_id,
    '0DiWol3AO6WpXZgp0goxAV',
    'One Dance',
    'Drake ft. Wizkid & Kyla',
    'https://i.scdn.co/image/ab67616d0000b273f46b9d202509a8f7384b90de',
    'Summer vibes incoming ☀️',
    'sent',
    NOW() - INTERVAL '3 days'
  ),
  -- From Jordan (4 days ago)
  (
    uuid_generate_v4(),
    jordan_id,
    current_user_id,
    '3DamFFqW32WihKkTVlwTYQ',
    'Levitating',
    'Dua Lipa ft. DaBaby',
    'https://i.scdn.co/image/ab67616d0000b273be841ba4bc24340152e3a79a',
    'This has been on repeat all week',
    'sent',
    NOW() - INTERVAL '4 days'
  ),
  -- From Taylor (5 days ago)
  (
    uuid_generate_v4(),
    taylor_id,
    current_user_id,
    '0sf6QqfHFJYhYQDSEYR1cK',
    'Watermelon Sugar',
    'Harry Styles',
    'https://i.scdn.co/image/ab67616d0000b2733c8896f56a1e09b234ce7e96',
    'Harry is just 🤌✨',
    'sent',
    NOW() - INTERVAL '5 days'
  );

  -- YOU SENT to friends
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  (
    uuid_generate_v4(),
    current_user_id,
    emma_id,
    '5Z01UMMf7V1o0MzF86s6WJ',
    'Starboy',
    'The Weeknd ft. Daft Punk',
    'https://i.scdn.co/image/ab67616d0000b2734718e2b124f79258be7bc452',
    'Thought you''d vibe with this!',
    'sent',
    NOW() - INTERVAL '6 hours'
  ),
  (
    uuid_generate_v4(),
    current_user_id,
    marcus_id,
    '2takcwOaAZWiXQijPHIx7B',
    'Time',
    'Pink Floyd',
    'https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe',
    'Classic',
    'sent',
    NOW() - INTERVAL '2 days'
  ),
  (
    uuid_generate_v4(),
    current_user_id,
    sofia_id,
    '4LRPiXqCikLlN15c3yImP7',
    'As It Was',
    'Harry Styles',
    'https://i.scdn.co/image/ab67616d0000b2732e8ed79e177ff6011076f5f0',
    'New Harry! 🎵',
    'sent',
    NOW() - INTERVAL '3 days'
  );

  -- FRIEND-TO-FRIEND shares (creates feed activity)
  INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  -- Emma → Marcus
  (
    emma_id,
    marcus_id,
    '4cOdK2wGLETKBW3PvgPWqT',
    'Sunflower',
    'Post Malone, Swae Lee',
    'https://i.scdn.co/image/ab67616d0000b273e2e352d89826aef6dbd5ff8f',
    'Spider-verse soundtrack hits different',
    'sent',
    NOW() - INTERVAL '8 hours'
  ),
  -- Marcus → Sofia
  (
    marcus_id,
    sofia_id,
    '7ytR5pFWmSjzHJIeQkgog4',
    'HUMBLE.',
    'Kendrick Lamar',
    'https://i.scdn.co/image/ab67616d0000b2738b52c6b9bc4e43d873869699',
    'Kendrick never misses',
    'played',
    NOW() - INTERVAL '12 hours'
  ),
  -- Sofia → Tyler
  (
    sofia_id,
    tyler_id,
    '3WMj8moIAXJhHsyLaqIIHI',
    'Peaches',
    'Justin Bieber ft. Daniel Caesar & Giveon',
    'https://i.scdn.co/image/ab67616d0000b273e6ca9cc11596dc34e8ac472d',
    'Smooth R&B vibes',
    'sent',
    NOW() - INTERVAL '1 day'
  ),
  -- Tyler → Alex
  (
    tyler_id,
    alex_id,
    '6DCZcSspjsKoFjzjrWoCdn',
    'God''s Plan',
    'Drake',
    'https://i.scdn.co/image/ab67616d0000b273f907de96b9a4fbc04accc0d5',
    'This beat goes crazy 🔥',
    'sent',
    NOW() - INTERVAL '2 days'
  );

  RAISE NOTICE 'Successfully created comprehensive dummy data!';
  RAISE NOTICE '  - 13 users created';
  RAISE NOTICE '  - 8 accepted friends';
  RAISE NOTICE '  - 2 pending friend requests';
  RAISE NOTICE '  - 3 users to discover';
  RAISE NOTICE '  - ~20 shares for feed activity';
  RAISE NOTICE 'You can now explore the full Phlock experience!';

END $$;
