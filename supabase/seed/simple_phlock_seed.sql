-- ⚠️⚠️⚠️ SIMPLIFIED DUMMY DATA SEED - FOR DEMO ONLY ⚠️⚠️⚠️
-- Purpose: CS1060 HW7 Demo - Phlock Visualization Feature
-- ⚠️⚠️⚠️ SIMPLIFIED DUMMY DATA SEED - FOR DEMO ONLY ⚠️⚠️⚠️

-- Clean existing dummy data
DELETE FROM phlock_nodes;
DELETE FROM phlocks;
DELETE FROM shares;
DELETE FROM users WHERE display_name LIKE 'Demo%';

-- Create 25 dummy users
INSERT INTO users (id, display_name, bio, profile_photo_url, platform_type, platform_user_id, created_at) VALUES
('11111111-1111-1111-1111-111111111111', 'Demo Alex Chen', 'indie enthusiast 🎸', 'https://i.pravatar.cc/150?img=1', 'spotify', 'demo_alex', NOW() - INTERVAL '6 months'),
('22222222-2222-2222-2222-222222222222', 'Demo Sarah Kim', 'always vibing ✨', 'https://i.pravatar.cc/150?img=2', 'spotify', 'demo_sarah', NOW() - INTERVAL '5 months'),
('33333333-3333-3333-3333-333333333333', 'Demo Marcus Johnson', 'hip hop head 🎤', 'https://i.pravatar.cc/150?img=3', 'spotify', 'demo_marcus', NOW() - INTERVAL '5 months'),
('44444444-4444-4444-4444-444444444444', 'Demo Emma Davis', 'coffee & chill beats ☕', 'https://i.pravatar.cc/150?img=4', 'spotify', 'demo_emma', NOW() - INTERVAL '4 months'),
('55555555-5555-5555-5555-555555555555', 'Demo Jake Rodriguez', 'edm all day everyday 🔊', 'https://i.pravatar.cc/150?img=5', 'spotify', 'demo_jake', NOW() - INTERVAL '4 months'),
('66666666-6666-6666-6666-666666666666', 'Demo Olivia Martinez', 'sad girl autumn 🍂', 'https://i.pravatar.cc/150?img=6', 'spotify', 'demo_olivia', NOW() - INTERVAL '3 months'),
('77777777-7777-7777-7777-777777777777', 'Demo Ryan Patel', 'beats & bass', 'https://i.pravatar.cc/150?img=7', 'spotify', 'demo_ryan', NOW() - INTERVAL '3 months'),
('88888888-8888-8888-8888-888888888888', 'Demo Sophie Turner', 'music is life 🎵', 'https://i.pravatar.cc/150?img=8', 'spotify', 'demo_sophie', NOW() - INTERVAL '3 months'),
('99999999-9999-9999-9999-999999999999', 'Demo Chris Lee', 'rock on 🤘', 'https://i.pravatar.cc/150?img=9', 'spotify', 'demo_chris', NOW() - INTERVAL '2 months'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Maya Foster', 'jazz & soul', 'https://i.pravatar.cc/150?img=10', 'spotify', 'demo_maya', NOW() - INTERVAL '2 months'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Demo Jordan Wu', 'playlist curator 📝', 'https://i.pravatar.cc/150?img=11', 'spotify', 'demo_jordan', NOW() - INTERVAL '2 months'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Demo Taylor Swift', 'not that taylor 😂', 'https://i.pravatar.cc/150?img=12', 'spotify', 'demo_taylor', NOW() - INTERVAL '1 month'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Demo Nathan Gray', 'discovering new sounds', 'https://i.pravatar.cc/150?img=13', 'spotify', 'demo_nathan', NOW() - INTERVAL '1 month'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Demo Isabella Moore', 'concert addict 🎤', 'https://i.pravatar.cc/150?img=14', 'spotify', 'demo_isabella', NOW() - INTERVAL '1 month'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Demo Ethan Clark', 'synth wave lover', 'https://i.pravatar.cc/150?img=15', 'spotify', 'demo_ethan', NOW() - INTERVAL '1 month'),
('10101010-1010-1010-1010-101010101010', 'Demo Ava Thompson', 'good vibes only ✌️', 'https://i.pravatar.cc/150?img=16', 'spotify', 'demo_ava', NOW() - INTERVAL '3 weeks'),
('11111110-1111-1111-1111-111111111110', 'Demo Lucas Brown', 'music producer', 'https://i.pravatar.cc/150?img=17', 'spotify', 'demo_lucas', NOW() - INTERVAL '3 weeks'),
('12121212-1212-1212-1212-121212121212', 'Demo Mia Anderson', 'party starter 🎉', 'https://i.pravatar.cc/150?img=18', 'spotify', 'demo_mia', NOW() - INTERVAL '2 weeks'),
('13131313-1313-1313-1313-131313131313', 'Demo Noah Wilson', 'finding my sound', 'https://i.pravatar.cc/150?img=19', 'spotify', 'demo_noah', NOW() - INTERVAL '2 weeks'),
('14141414-1414-1414-1414-141414141414', 'Demo Chloe Harris', 'music = therapy', 'https://i.pravatar.cc/150?img=20', 'spotify', 'demo_chloe', NOW() - INTERVAL '2 weeks'),
('15151515-1515-1515-1515-151515151515', 'Demo Liam Martin', 'late night vibes 🌙', 'https://i.pravatar.cc/150?img=21', 'spotify', 'demo_liam', NOW() - INTERVAL '1 week'),
('16161616-1616-1616-1616-161616161616', 'Demo Zoe Garcia', 'dance floor ready 💃', 'https://i.pravatar.cc/150?img=22', 'spotify', 'demo_zoe', NOW() - INTERVAL '1 week'),
('17171717-1717-1717-1717-171717171717', 'Demo Mason Lee', 'underground hits', 'https://i.pravatar.cc/150?img=23', 'spotify', 'demo_mason', NOW() - INTERVAL '1 week'),
('18181818-1818-1818-1818-181818181818', 'Demo Lily Chen', 'music journalist', 'https://i.pravatar.cc/150?img=24', 'spotify', 'demo_lily', NOW() - INTERVAL '5 days'),
('19191919-1919-1919-1919-191919191919', 'Demo Owen Park', 'always has airpods in 🎧', 'https://i.pravatar.cc/150?img=25', 'spotify', 'demo_owen', NOW() - INTERVAL '3 days');

-- Now create phlocks with proper nodes
DO $$
DECLARE
  current_user_id UUID;
  phlock1_id UUID := 'aa000000-0000-0000-0000-000000000001';
  phlock2_id UUID := 'aa000000-0000-0000-0000-000000000002';
  phlock3_id UUID := 'aa000000-0000-0000-0000-000000000003';
  root_node_id UUID;
BEGIN
  -- Get current user
  SELECT id INTO current_user_id FROM users
  WHERE display_name NOT LIKE 'Demo%'
  ORDER BY created_at ASC
  LIMIT 1;

  IF current_user_id IS NULL THEN
    current_user_id := '11111111-1111-1111-1111-111111111111';
  END IF;

  -- PHLOCK 1: Get Lucky (Viral Hit - 15 people, 3 generations)
  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock1_id, NULL, current_user_id, '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk',
          'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 15, 3, NOW() - INTERVAL '7 days');

  -- Root node
  root_node_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node_id, phlock1_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Generation 1 (4 people)
  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  SELECT phlock1_id, id, 1, root_node_id, TRUE, TRUE, TRUE
  FROM (VALUES
    ('11111111-1111-1111-1111-111111111111'::uuid),
    ('22222222-2222-2222-2222-222222222222'::uuid),
    ('33333333-3333-3333-3333-333333333333'::uuid),
    ('44444444-4444-4444-4444-444444444444'::uuid)
  ) AS v(id);

  -- Generation 2 (6 people)
  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  SELECT phlock1_id, user_id, 2,
         (SELECT id FROM phlock_nodes WHERE phlock_id = phlock1_id AND depth = 1 LIMIT 1),
         (RANDOM() > 0.5), (RANDOM() > 0.3), TRUE
  FROM (VALUES
    ('55555555-5555-5555-5555-555555555555'::uuid),
    ('66666666-6666-6666-6666-666666666666'::uuid),
    ('77777777-7777-7777-7777-777777777777'::uuid),
    ('88888888-8888-8888-8888-888888888888'::uuid),
    ('99999999-9999-9999-9999-999999999999'::uuid),
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid)
  ) AS v(user_id);

  -- Generation 3 (5 people)
  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  SELECT phlock1_id, user_id, 3,
         (SELECT id FROM phlock_nodes WHERE phlock_id = phlock1_id AND depth = 2 LIMIT 1),
         FALSE, (RANDOM() > 0.4), TRUE
  FROM (VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
  ) AS v(user_id);

  -- PHLOCK 2: Bloom (Intimate Circle - 5 people, 100% save)
  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock2_id, NULL, current_user_id, '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites',
          'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 5, 2, NOW() - INTERVAL '3 days');

  root_node_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node_id, phlock2_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  SELECT phlock2_id, id, 1, root_node_id, FALSE, TRUE, TRUE
  FROM (VALUES
    ('11111111-1111-1111-1111-111111111111'::uuid),
    ('22222222-2222-2222-2222-222222222222'::uuid),
    ('44444444-4444-4444-4444-444444444444'::uuid)
  ) AS v(id);

  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  SELECT phlock2_id, user_id, 2,
         (SELECT id FROM phlock_nodes WHERE phlock_id = phlock2_id AND depth = 1 LIMIT 1),
         FALSE, TRUE, TRUE
  FROM (VALUES
    ('77777777-7777-7777-7777-777777777777'::uuid)
  ) AS v(user_id);

  -- PHLOCK 3: Quantum Dreams (Failed Launch - 5 people, 20% save)
  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock3_id, NULL, current_user_id, 'experimental123', 'Quantum Dreams', 'Unknown Artist',
          'https://i.pravatar.cc/300?img=60', 5, 1, NOW() - INTERVAL '5 days');

  root_node_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node_id, phlock3_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES
    (phlock3_id, '33333333-3333-3333-3333-333333333333', 1, root_node_id, FALSE, TRUE, TRUE),
    (phlock3_id, '55555555-5555-5555-5555-555555555555', 1, root_node_id, FALSE, FALSE, FALSE),
    (phlock3_id, '77777777-7777-7777-7777-777777777777', 1, root_node_id, FALSE, FALSE, TRUE),
    (phlock3_id, '99999999-9999-9999-9999-999999999999', 1, root_node_id, FALSE, FALSE, FALSE);

  RAISE NOTICE '✅ Phlock seed data created successfully!';
  RAISE NOTICE 'Created 3 phlocks for user: %', current_user_id;
  RAISE NOTICE '1. Viral Hit: Get Lucky (15 people, 3 generations)';
  RAISE NOTICE '2. Intimate Circle: Bloom (5 people, 2 generations, 100%% save rate)';
  RAISE NOTICE '3. Failed Launch: Quantum Dreams (5 people, 1 generation, 20%% save rate)';
END $$;
