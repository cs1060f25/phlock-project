-- ⚠️⚠️⚠️ COMPLETE DUMMY DATA SEED FILE - FOR DEMO ONLY ⚠️⚠️⚠️
-- This file populates phlock tables with realistic demonstration data
-- Purpose: CS1060 HW7 Demo - Show compelling phlock visualizations
--
-- IMPORTANT: This file assumes:
-- 1. The migration 20241029000000_create_phlock_tables_DUMMY_DATA.sql has been run
-- 2. There is at least one real user in the users table (the current logged-in user)
--
-- The seed data will link phlocks to the first user found in the users table
-- ⚠️⚠️⚠️ COMPLETE DUMMY DATA SEED FILE - FOR DEMO ONLY ⚠️⚠️⚠️

-- Clean existing dummy data (if re-running)
DELETE FROM phlock_nodes;
DELETE FROM phlocks;
DELETE FROM shares;
DELETE FROM users WHERE display_name LIKE 'Demo%';

-- ====================
-- CREATE DUMMY USERS
-- ====================
-- Insert 25 realistic dummy user accounts

INSERT INTO users (id, display_name, bio, profile_photo_url, platform_type, platform_user_id, created_at) VALUES
-- Row 1: Close friends
('11111111-1111-1111-1111-111111111111', 'Demo Alex Chen', 'indie enthusiast 🎸', 'https://i.pravatar.cc/150?img=1', 'spotify', 'demo_alex', NOW() - INTERVAL '6 months'),
('22222222-2222-2222-2222-222222222222', 'Demo Sarah Kim', 'always vibing ✨', 'https://i.pravatar.cc/150?img=2', 'spotify', 'demo_sarah', NOW() - INTERVAL '5 months'),
('33333333-3333-3333-3333-333333333333', 'Demo Marcus Johnson', 'hip hop head 🎤', 'https://i.pravatar.cc/150?img=3', 'spotify', 'demo_marcus', NOW() - INTERVAL '5 months'),
('44444444-4444-4444-4444-444444444444', 'Demo Emma Davis', 'coffee & chill beats ☕', 'https://i.pravatar.cc/150?img=4', 'spotify', 'demo_emma', NOW() - INTERVAL '4 months'),
('55555555-5555-5555-5555-555555555555', 'Demo Jake Rodriguez', 'edm all day everyday 🔊', 'https://i.pravatar.cc/150?img=5', 'spotify', 'demo_jake', NOW() - INTERVAL '4 months'),
('66666666-6666-6666-6666-666666666666', 'Demo Olivia Martinez', 'sad girl autumn 🍂', 'https://i.pravatar.cc/150?img=6', 'spotify', 'demo_olivia', NOW() - INTERVAL '3 months'),

-- Row 2: Extended network
('77777777-7777-7777-7777-777777777777', 'Demo Ryan Patel', 'beats & bass', 'https://i.pravatar.cc/150?img=7', 'spotify', 'demo_ryan', NOW() - INTERVAL '3 months'),
('88888888-8888-8888-8888-888888888888', 'Demo Sophie Turner', 'music is life 🎵', 'https://i.pravatar.cc/150?img=8', 'spotify', 'demo_sophie', NOW() - INTERVAL '3 months'),
('99999999-9999-9999-9999-999999999999', 'Demo Chris Lee', 'rock on 🤘', 'https://i.pravatar.cc/150?img=9', 'spotify', 'demo_chris', NOW() - INTERVAL '2 months'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Demo Maya Foster', 'jazz & soul', 'https://i.pravatar.cc/150?img=10', 'spotify', 'demo_maya', NOW() - INTERVAL '2 months'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Demo Jordan Wu', 'playlist curator 📝', 'https://i.pravatar.cc/150?img=11', 'spotify', 'demo_jordan', NOW() - INTERVAL '2 months'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Demo Taylor Swift', 'not that taylor 😂', 'https://i.pravatar.cc/150?img=12', 'spotify', 'demo_taylor', NOW() - INTERVAL '1 month'),

-- Row 3: Third generation
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Demo Nathan Gray', 'discovering new sounds', 'https://i.pravatar.cc/150?img=13', 'spotify', 'demo_nathan', NOW() - INTERVAL '1 month'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Demo Isabella Moore', 'concert addict 🎤', 'https://i.pravatar.cc/150?img=14', 'spotify', 'demo_isabella', NOW() - INTERVAL '1 month'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Demo Ethan Clark', 'synth wave lover', 'https://i.pravatar.cc/150?img=15', 'spotify', 'demo_ethan', NOW() - INTERVAL '1 month'),
('10101010-1010-1010-1010-101010101010', 'Demo Ava Thompson', 'good vibes only ✌️', 'https://i.pravatar.cc/150?img=16', 'spotify', 'demo_ava', NOW() - INTERVAL '3 weeks'),
('11111110-1111-1111-1111-111111111110', 'Demo Lucas Brown', 'music producer', 'https://i.pravatar.cc/150?img=17', 'spotify', 'demo_lucas', NOW() - INTERVAL '3 weeks'),
('12121212-1212-1212-1212-121212121212', 'Demo Mia Anderson', 'party starter 🎉', 'https://i.pravatar.cc/150?img=18', 'spotify', 'demo_mia', NOW() - INTERVAL '2 weeks'),

-- Row 4: Fourth generation (for viral phlock)
('13131313-1313-1313-1313-131313131313', 'Demo Noah Wilson', 'finding my sound', 'https://i.pravatar.cc/150?img=19', 'spotify', 'demo_noah', NOW() - INTERVAL '2 weeks'),
('14141414-1414-1414-1414-141414141414', 'Demo Chloe Harris', 'music = therapy', 'https://i.pravatar.cc/150?img=20', 'spotify', 'demo_chloe', NOW() - INTERVAL '2 weeks'),
('15151515-1515-1515-1515-151515151515', 'Demo Liam Martin', 'late night vibes 🌙', 'https://i.pravatar.cc/150?img=21', 'spotify', 'demo_liam', NOW() - INTERVAL '1 week'),
('16161616-1616-1616-1616-161616161616', 'Demo Zoe Garcia', 'dance floor ready 💃', 'https://i.pravatar.cc/150?img=22', 'spotify', 'demo_zoe', NOW() - INTERVAL '1 week'),
('17171717-1717-1717-1717-171717171717', 'Demo Mason Lee', 'underground hits', 'https://i.pravatar.cc/150?img=23', 'spotify', 'demo_mason', NOW() - INTERVAL '1 week'),
('18181818-1818-1818-1818-181818181818', 'Demo Lily Chen', 'music journalist', 'https://i.pravatar.cc/150?img=24', 'spotify', 'demo_lily', NOW() - INTERVAL '5 days'),
('19191919-1919-1919-1919-191919191919', 'Demo Owen Park', 'always has airpods in 🎧', 'https://i.pravatar.cc/150?img=25', 'spotify', 'demo_owen', NOW() - INTERVAL '3 days');

-- ====================
-- CREATE PHLOCKS WITH COMPLETE DATA
-- ====================

DO $$
DECLARE
  current_user_id UUID;
  phlock1_id UUID := 'aa000000-0000-0000-0000-000000000001';
  phlock2_id UUID := 'aa000000-0000-0000-0000-000000000002';
  phlock3_id UUID := 'aa000000-0000-0000-0000-000000000003';
  phlock4_id UUID := 'aa000000-0000-0000-0000-000000000004';
  phlock5_id UUID := 'aa000000-0000-0000-0000-000000000005';

  -- Root nodes for each phlock
  root_node1_id UUID;
  root_node2_id UUID;
  root_node3_id UUID;
  root_node4_id UUID;
  root_node5_id UUID;

  -- Helper variables for building hierarchies
  temp_node_id UUID;
  gen1_nodes UUID[];
  gen2_nodes UUID[];
  gen3_nodes UUID[];
BEGIN
  -- Get first real user (assumes at least one user exists)
  SELECT id INTO current_user_id FROM users
  WHERE display_name NOT LIKE 'Demo%'
  ORDER BY created_at ASC
  LIMIT 1;

  -- If no real user exists, use demo user
  IF current_user_id IS NULL THEN
    current_user_id := '11111111-1111-1111-1111-111111111111';
  END IF;

  -- ================================================================================
  -- PHLOCK 1: Get Lucky by Daft Punk (VIRAL HIT)
  -- Pattern: 1 → 6 → 12 → 8 → 3 (29 total people, 4 generations)
  -- High engagement, exponential spread
  -- ================================================================================

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock1_id, NULL, current_user_id, '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk',
          'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 29, 4, NOW() - INTERVAL '7 days');

  -- Root node (you)
  root_node1_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node1_id, phlock1_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Generation 1: 6 direct friends (high engagement)
  gen1_nodes := ARRAY[]::UUID[];
  FOR i IN 1..6 LOOP
    temp_node_id := uuid_generate_v4();
    gen1_nodes := array_append(gen1_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock1_id,
            CASE i
              WHEN 1 THEN '11111111-1111-1111-1111-111111111111'::uuid
              WHEN 2 THEN '22222222-2222-2222-2222-222222222222'::uuid
              WHEN 3 THEN '33333333-3333-3333-3333-333333333333'::uuid
              WHEN 4 THEN '44444444-4444-4444-4444-444444444444'::uuid
              WHEN 5 THEN '55555555-5555-5555-5555-555555555555'::uuid
              WHEN 6 THEN '66666666-6666-6666-6666-666666666666'::uuid
            END,
            1, root_node1_id, TRUE, (i % 2 = 0), TRUE);
  END LOOP;

  -- Generation 2: 12 people (spreading widely)
  gen2_nodes := ARRAY[]::UUID[];
  FOR i IN 1..12 LOOP
    temp_node_id := uuid_generate_v4();
    gen2_nodes := array_append(gen2_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock1_id,
            CASE i
              WHEN 1 THEN '77777777-7777-7777-7777-777777777777'::uuid
              WHEN 2 THEN '88888888-8888-8888-8888-888888888888'::uuid
              WHEN 3 THEN '99999999-9999-9999-9999-999999999999'::uuid
              WHEN 4 THEN 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
              WHEN 5 THEN 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
              WHEN 6 THEN 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid
              WHEN 7 THEN 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid
              WHEN 8 THEN 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid
              WHEN 9 THEN 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid
              WHEN 10 THEN '10101010-1010-1010-1010-101010101010'::uuid
              WHEN 11 THEN '11111110-1111-1111-1111-111111111110'::uuid
              WHEN 12 THEN '12121212-1212-1212-1212-121212121212'::uuid
            END,
            2, gen1_nodes[((i - 1) % 6) + 1], (i % 3 != 0), (i % 4 = 0), TRUE);
  END LOOP;

  -- Generation 3: 8 people (still spreading)
  gen3_nodes := ARRAY[]::UUID[];
  FOR i IN 1..8 LOOP
    temp_node_id := uuid_generate_v4();
    gen3_nodes := array_append(gen3_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock1_id,
            CASE i
              WHEN 1 THEN '13131313-1313-1313-1313-131313131313'::uuid
              WHEN 2 THEN '14141414-1414-1414-1414-141414141414'::uuid
              WHEN 3 THEN '15151515-1515-1515-1515-151515151515'::uuid
              WHEN 4 THEN '16161616-1616-1616-1616-161616161616'::uuid
              WHEN 5 THEN '17171717-1717-1717-1717-171717171717'::uuid
              WHEN 6 THEN '18181818-1818-1818-1818-181818181818'::uuid
              WHEN 7 THEN '19191919-1919-1919-1919-191919191919'::uuid
              -- Reuse user for realistic cross-connections
              WHEN 8 THEN '77777777-7777-7777-7777-777777777777'::uuid
            END,
            3, gen2_nodes[((i - 1) % 12) + 1], (i <= 2), (i % 3 = 0), TRUE);
  END LOOP;

  -- Generation 4: 3 final nodes (tapering off)
  FOR i IN 1..3 LOOP
    INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (phlock1_id,
            CASE i
              WHEN 1 THEN 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid -- Maya (reappears)
              WHEN 2 THEN 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid -- Isabella (reappears)
              WHEN 3 THEN 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid -- Jordan (reappears)
            END,
            4, gen3_nodes[((i - 1) % 8) + 1], FALSE, FALSE, TRUE);
  END LOOP;

  -- ================================================================================
  -- PHLOCK 2: Bloom by The Paper Kites (INTIMATE CIRCLE)
  -- Pattern: 1 → 3 → 2 (6 total people, 2 generations, 100% save rate)
  -- Small, tight-knit group with perfect engagement
  -- ================================================================================

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock2_id, NULL, current_user_id, '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites',
          'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 6, 2, NOW() - INTERVAL '3 days');

  root_node2_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node2_id, phlock2_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Gen 1: 3 close friends (all save)
  gen1_nodes := ARRAY[]::UUID[];
  FOR i IN 1..3 LOOP
    temp_node_id := uuid_generate_v4();
    gen1_nodes := array_append(gen1_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock2_id,
            CASE i
              WHEN 1 THEN '11111111-1111-1111-1111-111111111111'::uuid
              WHEN 2 THEN '22222222-2222-2222-2222-222222222222'::uuid
              WHEN 3 THEN '44444444-4444-4444-4444-444444444444'::uuid
            END,
            1, root_node2_id, (i = 2), TRUE, TRUE);
  END LOOP;

  -- Gen 2: 2 people (one person shares forward)
  FOR i IN 1..2 LOOP
    INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (phlock2_id,
            CASE i
              WHEN 1 THEN '77777777-7777-7777-7777-777777777777'::uuid
              WHEN 2 THEN '66666666-6666-6666-6666-666666666666'::uuid
            END,
            2, gen1_nodes[2], FALSE, TRUE, TRUE);
  END LOOP;

  -- ================================================================================
  -- PHLOCK 3: Quantum Dreams by Unknown Artist (FAILED LAUNCH)
  -- Pattern: 1 → 5 → 0 (6 people, 1 generation, 20% save rate)
  -- Shows what happens when a track doesn't resonate
  -- ================================================================================

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock3_id, NULL, current_user_id, 'experimental123', 'Quantum Dreams', 'Unknown Artist',
          'https://i.pravatar.cc/300?img=60', 6, 1, NOW() - INTERVAL '5 days');

  root_node3_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node3_id, phlock3_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Gen 1: 5 people, mostly dismiss (only 1 saves)
  FOR i IN 1..5 LOOP
    INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (phlock3_id,
            CASE i
              WHEN 1 THEN '33333333-3333-3333-3333-333333333333'::uuid
              WHEN 2 THEN '55555555-5555-5555-5555-555555555555'::uuid
              WHEN 3 THEN '77777777-7777-7777-7777-777777777777'::uuid
              WHEN 4 THEN '99999999-9999-9999-9999-999999999999'::uuid
              WHEN 5 THEN 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
            END,
            1, root_node3_id, FALSE, (i = 1), (i <= 3));
  END LOOP;

  -- ================================================================================
  -- PHLOCK 4: Pink + White by Frank Ocean (SLOW BURN)
  -- Pattern: 1 → 4 → 3 → 3 (11 people, 3 generations, gradual spread)
  -- Takes time to spread but maintains steady engagement
  -- ================================================================================

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock4_id, NULL, current_user_id, '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean',
          'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 11, 3, NOW() - INTERVAL '14 days');

  root_node4_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node4_id, phlock4_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Gen 1: 4 people
  gen1_nodes := ARRAY[]::UUID[];
  FOR i IN 1..4 LOOP
    temp_node_id := uuid_generate_v4();
    gen1_nodes := array_append(gen1_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock4_id,
            CASE i
              WHEN 1 THEN '11111111-1111-1111-1111-111111111111'::uuid
              WHEN 2 THEN '66666666-6666-6666-6666-666666666666'::uuid
              WHEN 3 THEN '88888888-8888-8888-8888-888888888888'::uuid
              WHEN 4 THEN 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
            END,
            1, root_node4_id, (i = 1 OR i = 3), (i % 2 = 0), TRUE);
  END LOOP;

  -- Gen 2: 3 people
  gen2_nodes := ARRAY[]::UUID[];
  FOR i IN 1..3 LOOP
    temp_node_id := uuid_generate_v4();
    gen2_nodes := array_append(gen2_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock4_id,
            CASE i
              WHEN 1 THEN '33333333-3333-3333-3333-333333333333'::uuid
              WHEN 2 THEN '55555555-5555-5555-5555-555555555555'::uuid
              WHEN 3 THEN '99999999-9999-9999-9999-999999999999'::uuid
            END,
            2, gen1_nodes[CASE WHEN i = 1 THEN 1 WHEN i = 2 THEN 1 ELSE 3 END], (i = 1 OR i = 3), (i = 2), TRUE);
  END LOOP;

  -- Gen 3: 3 people
  FOR i IN 1..3 LOOP
    INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (phlock4_id,
            CASE i
              WHEN 1 THEN 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid
              WHEN 2 THEN 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid
              WHEN 3 THEN 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid
            END,
            3, gen2_nodes[CASE WHEN i = 1 THEN 1 ELSE 3 END], FALSE, TRUE, TRUE);
  END LOOP;

  -- ================================================================================
  -- PHLOCK 5: SICKO MODE by Travis Scott (ECHO CHAMBER)
  -- Pattern: 1 → 4 → dense cross-connections (10 people, 2 generations)
  -- High density network where people share within same group
  -- ================================================================================

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock5_id, NULL, current_user_id, '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott',
          'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 10, 2, NOW() - INTERVAL '2 days');

  root_node5_id := uuid_generate_v4();
  INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node5_id, phlock5_id, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Gen 1: 4 people (all forward)
  gen1_nodes := ARRAY[]::UUID[];
  FOR i IN 1..4 LOOP
    temp_node_id := uuid_generate_v4();
    gen1_nodes := array_append(gen1_nodes, temp_node_id);
    INSERT INTO phlock_nodes (id, phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (temp_node_id, phlock5_id,
            CASE i
              WHEN 1 THEN '33333333-3333-3333-3333-333333333333'::uuid
              WHEN 2 THEN '55555555-5555-5555-5555-555555555555'::uuid
              WHEN 3 THEN '77777777-7777-7777-7777-777777777777'::uuid
              WHEN 4 THEN '99999999-9999-9999-9999-999999999999'::uuid
            END,
            1, root_node5_id, TRUE, (i = 4), TRUE);
  END LOOP;

  -- Gen 2: 6 people (dense connections - some receive from multiple people)
  FOR i IN 1..6 LOOP
    INSERT INTO phlock_nodes (phlock_id, user_id, depth, parent_node_id, forwarded, saved, played)
    VALUES (phlock5_id,
            CASE i
              WHEN 1 THEN 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
              WHEN 2 THEN 'cccccccc-cccc-cccc-cccc-cccccccccccc'::uuid
              WHEN 3 THEN 'dddddddd-dddd-dddd-dddd-dddddddddddd'::uuid
              WHEN 4 THEN 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'::uuid
              WHEN 5 THEN 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid
              WHEN 6 THEN '10101010-1010-1010-1010-101010101010'::uuid
            END,
            2, gen1_nodes[((i - 1) % 4) + 1], FALSE, (i % 2 = 0), TRUE);
  END LOOP;

  RAISE NOTICE '✅ Phlock seed data created successfully!';
  RAISE NOTICE 'Created 5 diverse phlocks for user: %', current_user_id;
  RAISE NOTICE '1. VIRAL HIT: Get Lucky by Daft Punk (29 people, 4 generations)';
  RAISE NOTICE '   - Exponential spread, high engagement, shows true virality';
  RAISE NOTICE '2. INTIMATE CIRCLE: Bloom by The Paper Kites (6 people, 2 generations, 100%% save)';
  RAISE NOTICE '   - Small tight-knit group, perfect engagement';
  RAISE NOTICE '3. FAILED LAUNCH: Quantum Dreams by Unknown Artist (6 people, 1 generation, 20%% save)';
  RAISE NOTICE '   - Shows what happens when music does not resonate';
  RAISE NOTICE '4. SLOW BURN: Pink + White by Frank Ocean (11 people, 3 generations)';
  RAISE NOTICE '   - Gradual organic spread over 2 weeks';
  RAISE NOTICE '5. ECHO CHAMBER: SICKO MODE by Travis Scott (10 people, 2 generations)';
  RAISE NOTICE '   - Dense network with cross-connections within friend group';

END $$;

-- ⚠️⚠️⚠️ SEED DATA COMPLETE ⚠️⚠️⚠️
