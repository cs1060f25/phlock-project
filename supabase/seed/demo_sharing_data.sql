-- ============================================================================
-- PHLOCK DEMO DATA: Song Sharing Test Data
-- ============================================================================
-- This script creates dummy users, friendships, and shares for testing
-- the song sharing feature with realistic data.
--
-- IMPORTANT: If your user ID is different, use Find & Replace to change
-- all instances of 'B1660762-C5CA-4389-9461-72D505E52EBB' to your actual ID
-- ============================================================================

-- ============================================================================
-- STEP 1: Create Dummy Friend Users
-- ============================================================================

-- User 1: Sarah Chen (Indie/Alternative music lover)
INSERT INTO users (id, email, display_name, profile_photo_url, bio, platform_type, platform_user_id, platform_data, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  'sarah.chen.demo@phlock.test',
  'Sarah Chen',
  'https://i.pravatar.cc/150?img=5',
  'indie music enthusiast 🎵',
  'spotify',
  'sarah_spotify_12345',
  jsonb_build_object(
    'top_artists', jsonb_build_array(
      jsonb_build_object('id', '2QY7LuVcMv1nlOZnYrvU2C', 'name', 'The Paper Kites'),
      jsonb_build_object('id', '1r1uxoy19fzMxunt3ONAkG', 'name', 'Phoebe Bridgers'),
      jsonb_build_object('id', '4LEiUm1SRbFMgfqnQTwUbQ', 'name', 'Bon Iver')
    )
  ),
  NOW() - INTERVAL '3 months'
)
ON CONFLICT (id) DO NOTHING;

-- User 2: Mike Rodriguez (Hip-Hop/R&B)
INSERT INTO users (id, email, display_name, profile_photo_url, bio, platform_type, platform_user_id, platform_data, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440002',
  'mike.rodriguez.demo@phlock.test',
  'Mike Rodriguez',
  'https://i.pravatar.cc/150?img=12',
  'hip-hop head | always looking for new beats',
  'spotify',
  'mike_spotify_67890',
  jsonb_build_object(
    'top_artists', jsonb_build_array(
      jsonb_build_object('id', '0Y5tJX1MQlPlqiwlOH1tJY', 'name', 'Travis Scott'),
      jsonb_build_object('id', '2h93pZq0e7k5yf4dywlkpM', 'name', 'Frank Ocean'),
      jsonb_build_object('id', '7tYKF4w9nC0nq9CsPZTHyP', 'name', 'SZA')
    )
  ),
  NOW() - INTERVAL '2 months'
)
ON CONFLICT (id) DO NOTHING;

-- User 3: Alex Kim (Electronic/Pop)
INSERT INTO users (id, email, display_name, profile_photo_url, bio, platform_type, platform_user_id, platform_data, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440003',
  'alex.kim.demo@phlock.test',
  'Alex Kim',
  'https://i.pravatar.cc/150?img=8',
  'EDM lover 🎧 | festival season is my favorite season',
  'apple_music',
  'alex_apple_11111',
  jsonb_build_object(
    'top_artists', jsonb_build_array(
      jsonb_build_object('id', '4tZwfgrHOc3mvqYlEYSvVi', 'name', 'Daft Punk'),
      jsonb_build_object('id', '0XbSoNPv5O82DFh2OMnk8D', 'name', 'ODESZA'),
      jsonb_build_object('id', '6nS5roXSAGhTGr34W6n7Et', 'name', 'Disclosure')
    )
  ),
  NOW() - INTERVAL '4 months'
)
ON CONFLICT (id) DO NOTHING;

-- User 4: Emma Thompson (Pop/Singer-Songwriter)
INSERT INTO users (id, email, display_name, profile_photo_url, bio, platform_type, platform_user_id, platform_data, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440004',
  'emma.thompson.demo@phlock.test',
  'Emma Thompson',
  'https://i.pravatar.cc/150?img=20',
  'swiftie forever 💕',
  'spotify',
  'emma_spotify_22222',
  jsonb_build_object(
    'top_artists', jsonb_build_array(
      jsonb_build_object('id', '06HL4z0CvFAxyc27GXpf02', 'name', 'Taylor Swift'),
      jsonb_build_object('id', '163tK9Wjr9P9DmM0AVK7lm', 'name', 'Lorde'),
      jsonb_build_object('id', '00FQb4jTyendYWaN8pK0wa', 'name', 'Lana Del Rey')
    )
  ),
  NOW() - INTERVAL '1 month'
)
ON CONFLICT (id) DO NOTHING;

-- User 5: Jordan Lee (Rock/Alternative)
INSERT INTO users (id, email, display_name, profile_photo_url, bio, platform_type, platform_user_id, platform_data, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440005',
  'jordan.lee.demo@phlock.test',
  'Jordan Lee',
  'https://i.pravatar.cc/150?img=15',
  'rock on 🎸',
  'apple_music',
  'jordan_apple_33333',
  jsonb_build_object(
    'top_artists', jsonb_build_array(
      jsonb_build_object('id', '7Ln80lUS6He07XvHI8qqHH', 'name', 'Arctic Monkeys'),
      jsonb_build_object('id', '0epOFNiUfyON9EYx7Tpr6V', 'name', 'The Strokes'),
      jsonb_build_object('id', '5INjqkS1o8h1imAzPqGZBb', 'name', 'Tame Impala')
    )
  ),
  NOW() - INTERVAL '5 months'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- STEP 2: Create Accepted Friendships
-- ============================================================================

-- Friendship with Sarah
INSERT INTO friendships (user_id_1, user_id_2, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440001',
  'accepted',
  NOW() - INTERVAL '2 months'
)
ON CONFLICT DO NOTHING;

-- Friendship with Mike
INSERT INTO friendships (user_id_1, user_id_2, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440002',
  'accepted',
  NOW() - INTERVAL '1 month'
)
ON CONFLICT DO NOTHING;

-- Friendship with Alex
INSERT INTO friendships (user_id_1, user_id_2, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440003',
  'accepted',
  NOW() - INTERVAL '3 months'
)
ON CONFLICT DO NOTHING;

-- Friendship with Emma
INSERT INTO friendships (user_id_1, user_id_2, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440004',
  'accepted',
  NOW() - INTERVAL '3 weeks'
)
ON CONFLICT DO NOTHING;

-- Friendship with Jordan
INSERT INTO friendships (user_id_1, user_id_2, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440005',
  'accepted',
  NOW() - INTERVAL '4 months'
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 3: Create Received Shares (Your Inbox)
-- ============================================================================

-- From Sarah: "Bloom" by The Paper Kites (TODAY - 2 hours ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '5U1tMecqLfOkPwAqKECEyp',
  'Bloom',
  'The Paper Kites',
  'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214',
  'This song reminds me of you! 🌸',
  'sent',
  NOW() - INTERVAL '2 hours'
)
ON CONFLICT DO NOTHING;

-- From Sarah: "Motion Sickness" by Phoebe Bridgers (TODAY - 4 hours ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '2aBxt7oAOOYneMQTshXgPm',
  'Motion Sickness',
  'Phoebe Bridgers',
  'https://i.scdn.co/image/ab67616d0000b2737da94816f-c707e2-ff-79a2e94a6c',
  'You need to hear this.',
  'sent',
  NOW() - INTERVAL '4 hours'
)
ON CONFLICT DO NOTHING;

-- From Mike: "SICKO MODE" by Travis Scott (TODAY - 1 hour ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440002',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '2xLMifQCjDGFmkHkpNLD9h',
  'SICKO MODE',
  'Travis Scott',
  'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3',
  '🔥🔥🔥',
  'sent',
  NOW() - INTERVAL '1 hour'
)
ON CONFLICT DO NOTHING;

-- From Mike: "Pink + White" by Frank Ocean (YESTERDAY - played)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440002',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '6POmp4rJZEHmC90pQDjxQW',
  'Pink + White',
  'Frank Ocean',
  'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526',
  'Such a vibe',
  'played',
  NOW() - INTERVAL '1 day'
)
ON CONFLICT DO NOTHING;

-- From Mike: "Kill Bill" by SZA (YESTERDAY - saved)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440002',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '3OHfY25tqY28d16oZczHc8',
  'Kill Bill',
  'SZA',
  'https://i.scdn.co/image/ab67616d0000b2730c471c36970b9406233842a5',
  'you gotta hear this',
  'saved',
  NOW() - INTERVAL '1 day' - INTERVAL '6 hours'
)
ON CONFLICT DO NOTHING;

-- From Alex: "Get Lucky" by Daft Punk (THIS WEEK - 3 days ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440003',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '2Foc5Q5nqNiosCNqttzHof',
  'Get Lucky',
  'Daft Punk',
  'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937',
  'Peak summer vibes ☀️',
  'sent',
  NOW() - INTERVAL '3 days'
)
ON CONFLICT DO NOTHING;

-- From Alex: "Say My Name" by ODESZA (THIS WEEK - 4 days ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440003',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '3P2w3HG5hZ4QZAxNJJAuWv',
  'Say My Name',
  'ODESZA',
  'https://i.scdn.co/image/ab67616d0000b2738a585e4bb0ef1ad3c1929b64',
  NULL,
  'sent',
  NOW() - INTERVAL '4 days'
)
ON CONFLICT DO NOTHING;

-- From Emma: "Anti-Hero" by Taylor Swift (THIS WEEK - 5 days ago, dismissed)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440004',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '0V3wPSX9ygBnCm8psDIegu',
  'Anti-Hero',
  'Taylor Swift',
  'https://i.scdn.co/image/ab67616d0000b273e0b60c608586d88252b8fbc0',
  'its me hi im the problem its me',
  'dismissed',
  NOW() - INTERVAL '5 days'
)
ON CONFLICT DO NOTHING;

-- From Jordan: "Do I Wanna Know?" by Arctic Monkeys (LAST MONTH)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  '550e8400-e29b-41d4-a716-446655440005',
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '5FVd6KXrgO9B3JPmC8OPst',
  'Do I Wanna Know?',
  'Arctic Monkeys',
  'https://i.scdn.co/image/ab67616d0000b2734ae1c4c5c45aabe565499163',
  'Classic track 🎸',
  'sent',
  NOW() - INTERVAL '32 days'
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 4: Create Sent Shares (Your Outbox)
-- ============================================================================

-- To Sarah: "Liability" by Lorde (2 days ago)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440001',
  '2aJDlirz6v2a4HREki98cP',
  'Liability',
  'Lorde',
  'https://i.scdn.co/image/ab67616d0000b273b0349a3b89014a21f237e-cd2',
  'Thought you would like this one',
  'sent',
  NOW() - INTERVAL '2 days'
)
ON CONFLICT DO NOTHING;

-- To Mike: "Nikes" by Frank Ocean (3 days ago, HE PLAYED IT!)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440002',
  '2EjXfH91m7f8HiJN1yQg97',
  'Nikes',
  'Frank Ocean',
  'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526',
  NULL,
  'played',
  NOW() - INTERVAL '3 days'
)
ON CONFLICT DO NOTHING;

-- To Alex: "One More Time" by Daft Punk (1 week ago, SAVED!)
INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at)
VALUES (
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  '550e8400-e29b-41d4-a716-446655440003',
  '0DiWol3AO6WpXZgp0goxAV',
  'One More Time',
  'Daft Punk',
  'https://i.scdn.co/image/ab67616d0000b273e5a25ed08d1e7e0fbb-440e1c',
  'You love Daft Punk right?',
  'saved',
  NOW() - INTERVAL '7 days'
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 5: Create Engagement Records
-- ============================================================================

-- Mike played "Nikes"
INSERT INTO engagements (share_id, user_id, action, created_at)
SELECT
  id,
  '550e8400-e29b-41d4-a716-446655440002',
  'played',
  created_at + INTERVAL '2 hours'
FROM shares
WHERE sender_id = 'B1660762-C5CA-4389-9461-72D505E52EBB'
  AND recipient_id = '550e8400-e29b-41d4-a716-446655440002'
  AND track_name = 'Nikes'
ON CONFLICT DO NOTHING;

-- Alex saved "One More Time"
INSERT INTO engagements (share_id, user_id, action, created_at)
SELECT
  id,
  '550e8400-e29b-41d4-a716-446655440003',
  'saved',
  created_at + INTERVAL '1 day'
FROM shares
WHERE sender_id = 'B1660762-C5CA-4389-9461-72D505E52EBB'
  AND recipient_id = '550e8400-e29b-41d4-a716-446655440003'
  AND track_name = 'One More Time'
ON CONFLICT DO NOTHING;

-- You played "Pink + White" from Mike
INSERT INTO engagements (share_id, user_id, action, created_at)
SELECT
  id,
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  'played',
  created_at + INTERVAL '30 minutes'
FROM shares
WHERE sender_id = '550e8400-e29b-41d4-a716-446655440002'
  AND recipient_id = 'B1660762-C5CA-4389-9461-72D505E52EBB'
  AND track_name = 'Pink + White'
ON CONFLICT DO NOTHING;

-- You saved "Kill Bill" from Mike
INSERT INTO engagements (share_id, user_id, action, created_at)
SELECT
  id,
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  'saved',
  created_at + INTERVAL '1 hour'
FROM shares
WHERE sender_id = '550e8400-e29b-41d4-a716-446655440002'
  AND recipient_id = 'B1660762-C5CA-4389-9461-72D505E52EBB'
  AND track_name = 'Kill Bill'
ON CONFLICT DO NOTHING;

-- You dismissed "Anti-Hero" from Emma
INSERT INTO engagements (share_id, user_id, action, created_at)
SELECT
  id,
  'B1660762-C5CA-4389-9461-72D505E52EBB',
  'dismissed',
  created_at + INTERVAL '10 minutes'
FROM shares
WHERE sender_id = '550e8400-e29b-41d4-a716-446655440004'
  AND recipient_id = 'B1660762-C5CA-4389-9461-72D505E52EBB'
  AND track_name = 'Anti-Hero'
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show summary
DO $$
DECLARE
  user_count INTEGER;
  friendship_count INTEGER;
  received_count INTEGER;
  sent_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM users WHERE id IN ('550e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440003', '550e8400-e29b-41d4-a716-446655440004', '550e8400-e29b-41d4-a716-446655440005');
  SELECT COUNT(*) INTO friendship_count FROM friendships WHERE user_id_1 = 'B1660762-C5CA-4389-9461-72D505E52EBB' OR user_id_2 = 'B1660762-C5CA-4389-9461-72D505E52EBB';
  SELECT COUNT(*) INTO received_count FROM shares WHERE recipient_id = 'B1660762-C5CA-4389-9461-72D505E52EBB';
  SELECT COUNT(*) INTO sent_count FROM shares WHERE sender_id = 'B1660762-C5CA-4389-9461-72D505E52EBB';

  RAISE NOTICE '============================================';
  RAISE NOTICE 'DUMMY DATA CREATION COMPLETE!';
  RAISE NOTICE '============================================';
  RAISE NOTICE 'Dummy users created: %', user_count;
  RAISE NOTICE 'Friendships created: %', friendship_count;
  RAISE NOTICE 'Shares received: %', received_count;
  RAISE NOTICE 'Shares sent: %', sent_count;
  RAISE NOTICE '============================================';
  RAISE NOTICE 'You can now test:';
  RAISE NOTICE '  - Feed view with % unread shares', received_count;
  RAISE NOTICE '  - QuickSendBar with % friends', friendship_count;
  RAISE NOTICE '  - Engagement tracking';
  RAISE NOTICE '  - Smart friend ranking';
  RAISE NOTICE '============================================';
END $$;
