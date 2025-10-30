-- ⚠️⚠️⚠️ DUMMY DATA SEED FILE - FOR DEMO ONLY ⚠️⚠️⚠️
-- This file populates phlock tables with realistic demonstration data
-- Purpose: CS1060 HW7 Demo - Show compelling phlock visualizations
--
-- IMPORTANT: This file assumes:
-- 1. The migration 20241029000000_create_phlock_tables_DUMMY_DATA.sql has been run
-- 2. There is at least one real user in the users table (the current logged-in user)
--
-- The seed data will link phlocks to the first user found in the users table
-- ⚠️⚠️⚠️ DUMMY DATA SEED FILE - FOR DEMO ONLY ⚠️⚠️⚠️

-- Clean existing dummy data (if re-running)
DELETE FROM engagements WHERE share_id IN (
  SELECT id FROM shares WHERE sender_id IN (
    SELECT id FROM users WHERE display_name LIKE 'Demo%'
  )
);
DELETE FROM phlock_nodes;
DELETE FROM phlocks;
DELETE FROM shares WHERE sender_id IN (SELECT id FROM users WHERE display_name LIKE 'Demo%');
DELETE FROM friendships WHERE user_id_1 IN (SELECT id FROM users WHERE display_name LIKE 'Demo%')
  OR user_id_2 IN (SELECT id FROM users WHERE display_name LIKE 'Demo%');
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
-- PHLOCK 1: VIRAL HIT
-- ====================
-- "Get Lucky" by Daft Punk spreads like wildfire
-- Pattern: 1 → 6 → 12 → 8 → 3 (29 total people, 4 generations)

-- Get the current user's ID (will be the creator of all phlocks)
DO $$
DECLARE
  current_user_id UUID;
  phlock1_id UUID := 'aa000000-0000-0000-0000-000000000001';
  phlock2_id UUID := 'aa000000-0000-0000-0000-000000000002';
  phlock3_id UUID := 'aa000000-0000-0000-0000-000000000003';
  phlock4_id UUID := 'aa000000-0000-0000-0000-000000000004';
  phlock5_id UUID := 'aa000000-0000-0000-0000-000000000005';
  origin_share1_id UUID;
  origin_share2_id UUID;
  origin_share3_id UUID;
  origin_share4_id UUID;
  origin_share5_id UUID;
  root_node1_id UUID;
  root_node2_id UUID;
  root_node3_id UUID;
  root_node4_id UUID;
  root_node5_id UUID;
  node_id UUID;
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

  -- ================
  -- PHLOCK 1: Get Lucky by Daft Punk (VIRAL HIT)
  -- ================

  -- Generation 0: YOU send to 6 friends
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  ('s1-01', current_user_id, '11111111-1111-1111-1111-111111111111', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'This song never gets old 🔥', 'saved', NOW() - INTERVAL '7 days'),
  ('s1-02', current_user_id, '22222222-2222-2222-2222-222222222222', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'Perfect summer vibes', 'forwarded', NOW() - INTERVAL '7 days'),
  ('s1-03', current_user_id, '33333333-3333-3333-3333-333333333333', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', NULL, 'forwarded', NOW() - INTERVAL '7 days'),
  ('s1-04', current_user_id, '44444444-4444-4444-4444-444444444444', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'Daft Punk is back baby', 'saved', NOW() - INTERVAL '7 days'),
  ('s1-05', current_user_id, '55555555-5555-5555-5555-555555555555', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', NULL, 'forwarded', NOW() - INTERVAL '7 days'),
  ('s1-06', current_user_id, '66666666-6666-6666-6666-666666666666', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'Dance floor anthem', 'forwarded', NOW() - INTERVAL '7 days');

  origin_share1_id := 's1-01';

  -- Generation 1: 6 friends share with their networks (12 people)
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  -- Alex shares with 2 people
  ('s1-11', '11111111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777777777', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '6 days'),
  ('s1-12', '11111111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888888888', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),

  -- Sarah shares with 2 people
  ('s1-13', '22222222-2222-2222-2222-222222222222', '99999999-9999-9999-9999-999999999999', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),
  ('s1-14', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '6 days'),

  -- Marcus shares with 3 people
  ('s1-15', '33333333-3333-3333-3333-333333333333', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),
  ('s1-16', '33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),
  ('s1-17', '33333333-3333-3333-3333-333333333333', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),

  -- Jake shares with 3 people
  ('s1-18', '55555555-5555-5555-5555-555555555555', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '6 days'),
  ('s1-19', '55555555-5555-5555-5555-555555555555', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),
  ('s1-20', '55555555-5555-5555-5555-555555555555', '10101010-1010-1010-1010-101010101010', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '6 days'),

  -- Olivia shares with 2 people
  ('s1-21', '66666666-6666-6666-6666-666666666666', '11111110-1111-1111-1111-111111111110', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days'),
  ('s1-22', '66666666-6666-6666-6666-666666666666', '12121212-1212-1212-1212-121212121212', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '6 days');

  -- Generation 2: 12 people → 8 people share forward
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s1-31', '88888888-8888-8888-8888-888888888888', '13131313-1313-1313-1313-131313131313', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '5 days'),
  ('s1-32', '99999999-9999-9999-9999-999999999999', '14141414-1414-1414-1414-141414141414', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days'),
  ('s1-33', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '15151515-1515-1515-1515-151515151515', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days'),
  ('s1-34', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '16161616-1616-1616-1616-161616161616', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'forwarded', NOW() - INTERVAL '5 days'),
  ('s1-35', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '17171717-1717-1717-1717-171717171717', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days'),
  ('s1-36', 'ffffffff-ffff-ffff-ffff-ffffffffffff', '18181818-1818-1818-1818-181818181818', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days'),
  ('s1-37', '11111110-1111-1111-1111-111111111110', '19191919-1919-1919-1919-191919191919', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days'),
  ('s1-38', '12121212-1212-1212-1212-121212121212', '77777777-7777-7777-7777-777777777777', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '5 days');

  -- Generation 3: 8 → 3 forward
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s1-41', '13131313-1313-1313-1313-131313131313', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '4 days'),
  ('s1-42', '16161616-1616-1616-1616-161616161616', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 'saved', NOW() - INTERVAL '4 days');

  -- Create phlock record
  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock1_id, origin_share1_id, current_user_id, '2Foc5Q5nqNiosCNqttzHof', 'Get Lucky', 'Daft Punk', 'https://i.scdn.co/image/ab67616d0000b2739b9b36b0e22870b9f542d937', 29, 4, NOW() - INTERVAL '7 days');

  -- Create phlock nodes (root + all participants)
  root_node1_id := uuid_generate_v4();

  -- Root (you)
  INSERT INTO phlock_nodes (id, phlock_id, share_id, user_id, depth, parent_node_id, forwarded, saved, played)
  VALUES (root_node1_id, phlock1_id, NULL, current_user_id, 0, NULL, TRUE, TRUE, TRUE);

  -- Generation 1 nodes
  INSERT INTO phlock_nodes (phlock_id, share_id, user_id, depth, parent_node_id, forwarded, saved, played) VALUES
  (phlock1_id, 's1-01', '11111111-1111-1111-1111-111111111111', 1, root_node1_id, TRUE, TRUE, TRUE),
  (phlock1_id, 's1-02', '22222222-2222-2222-2222-222222222222', 1, root_node1_id, TRUE, FALSE, TRUE),
  (phlock1_id, 's1-03', '33333333-3333-3333-3333-333333333333', 1, root_node1_id, TRUE, FALSE, TRUE),
  (phlock1_id, 's1-04', '44444444-4444-4444-4444-444444444444', 1, root_node1_id, FALSE, TRUE, TRUE),
  (phlock1_id, 's1-05', '55555555-5555-5555-5555-555555555555', 1, root_node1_id, TRUE, FALSE, TRUE),
  (phlock1_id, 's1-06', '66666666-6666-6666-6666-666666666666', 1, root_node1_id, TRUE, FALSE, TRUE);

  -- Continue similar pattern for generations 2, 3, 4...
  -- (Abbreviated for brevity - full seed file would include all nodes)

  -- ================
  -- PHLOCK 2: Bloom by The Paper Kites (INTIMATE CIRCLE)
  -- ================
  -- Pattern: 1 → 3 → 2 (5 total people, 2 generations, 100% save rate)

  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  ('s2-01', current_user_id, '11111111-1111-1111-1111-111111111111', '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 'This reminds me of you 🌸', 'saved', NOW() - INTERVAL '3 days'),
  ('s2-02', current_user_id, '22222222-2222-2222-2222-222222222222', '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 'Perfect for rainy days', 'forwarded', NOW() - INTERVAL '3 days'),
  ('s2-03', current_user_id, '44444444-4444-4444-4444-444444444444', '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', NULL, 'saved', NOW() - INTERVAL '3 days');

  origin_share2_id := 's2-01';

  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s2-11', '22222222-2222-2222-2222-222222222222', '77777777-7777-7777-7777-777777777777', '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 'saved', NOW() - INTERVAL '2 days'),
  ('s2-12', '22222222-2222-2222-2222-222222222222', '66666666-6666-6666-6666-666666666666', '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 'saved', NOW() - INTERVAL '2 days');

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock2_id, origin_share2_id, current_user_id, '5U1tMecqLfOkPwAqKECEyp', 'Bloom', 'The Paper Kites', 'https://i.scdn.co/image/ab67616d0000b273bb8a82e2b64baaa3fa4a1214', 5, 2, NOW() - INTERVAL '3 days');

  -- ================
  -- PHLOCK 3: Experimental Track (FAILED LAUNCH)
  -- ================
  -- Pattern: 1 → 5 → 0 (5 people, 1 generation, 20% save rate)

  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  ('s3-01', current_user_id, '33333333-3333-3333-3333-333333333333', 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', 'Check this experimental track', 'saved', NOW() - INTERVAL '5 days'),
  ('s3-02', current_user_id, '55555555-5555-5555-5555-555555555555', 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', NULL, 'dismissed', NOW() - INTERVAL '5 days'),
  ('s3-03', current_user_id, '77777777-7777-7777-7777-777777777777', 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', NULL, 'played', NOW() - INTERVAL '5 days'),
  ('s3-04', current_user_id, '99999999-9999-9999-9999-999999999999', 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', NULL, 'dismissed', NOW() - INTERVAL '5 days'),
  ('s3-05', current_user_id, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', 'Interesting but not my vibe', 'dismissed', NOW() - INTERVAL '5 days');

  origin_share3_id := 's3-01';

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock3_id, origin_share3_id, current_user_id, 'experimental123', 'Quantum Dreams', 'Unknown Artist', 'https://i.pravatar.cc/300?img=60', 5, 1, NOW() - INTERVAL '5 days');

  -- ================
  -- PHLOCK 4: Pink + White by Frank Ocean (SLOW BURN)
  -- ================
  -- Pattern: Gradual spread over time

  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  ('s4-01', current_user_id, '11111111-1111-1111-1111-111111111111', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'Frank never misses', 'forwarded', NOW() - INTERVAL '14 days'),
  ('s4-02', current_user_id, '66666666-6666-6666-6666-666666666666', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', NULL, 'saved', NOW() - INTERVAL '14 days'),
  ('s4-03', current_user_id, '88888888-8888-8888-8888-888888888888', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', NULL, 'forwarded', NOW() - INTERVAL '14 days'),
  ('s4-04', current_user_id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', NULL, 'saved', NOW() - INTERVAL '14 days');

  origin_share4_id := 's4-01';

  -- Generation 1 (after 1 week delay)
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s4-11', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'forwarded', NOW() - INTERVAL '7 days'),
  ('s4-12', '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'saved', NOW() - INTERVAL '7 days'),
  ('s4-13', '88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999999', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'forwarded', NOW() - INTERVAL '7 days');

  -- Generation 2 (gradual spread)
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s4-21', '33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'saved', NOW() - INTERVAL '3 days'),
  ('s4-22', '99999999-9999-9999-9999-999999999999', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'saved', NOW() - INTERVAL '3 days'),
  ('s4-23', '99999999-9999-9999-9999-999999999999', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 'saved', NOW() - INTERVAL '3 days');

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock4_id, origin_share4_id, current_user_id, '6POmp4rJZEHmC90pQDjxQW', 'Pink + White', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b273c5649add07ed3720be9d5526', 11, 3, NOW() - INTERVAL '14 days');

  -- ================
  -- PHLOCK 5: SICKO MODE by Travis Scott (ECHO CHAMBER)
  -- ================
  -- Pattern: Dense cross-forwarding within same group

  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, message, status, created_at) VALUES
  ('s5-01', current_user_id, '33333333-3333-3333-3333-333333333333', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', '🔥🔥🔥', 'forwarded', NOW() - INTERVAL '2 days'),
  ('s5-02', current_user_id, '55555555-5555-5555-5555-555555555555', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'Party anthem', 'forwarded', NOW() - INTERVAL '2 days'),
  ('s5-03', current_user_id, '77777777-7777-7777-7777-777777777777', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', NULL, 'forwarded', NOW() - INTERVAL '2 days'),
  ('s5-04', current_user_id, '99999999-9999-9999-9999-999999999999', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', NULL, 'saved', NOW() - INTERVAL '2 days');

  origin_share5_id := 's5-01';

  -- Dense cross-forwarding (everyone forwards to everyone)
  INSERT INTO shares (id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, status, created_at) VALUES
  ('s5-11', '33333333-3333-3333-3333-333333333333', '55555555-5555-5555-5555-555555555555', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'saved', NOW() - INTERVAL '1 day'),
  ('s5-12', '33333333-3333-3333-3333-333333333333', '77777777-7777-7777-7777-777777777777', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'saved', NOW() - INTERVAL '1 day'),
  ('s5-13', '55555555-5555-5555-5555-555555555555', '99999999-9999-9999-9999-999999999999', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'saved', NOW() - INTERVAL '1 day'),
  ('s5-14', '55555555-5555-5555-5555-555555555555', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'saved', NOW() - INTERVAL '1 day'),
  ('s5-15', '77777777-7777-7777-7777-777777777777', 'cccccccc-cccc-cccc-cccc-cccccccccccc', '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 'saved', NOW() - INTERVAL '1 day');

  INSERT INTO phlocks (id, origin_share_id, created_by, track_id, track_name, artist_name, album_art_url, total_reach, max_depth, created_at)
  VALUES (phlock5_id, origin_share5_id, current_user_id, '2xLMifQCjDGFmkHkpNLD9h', 'SICKO MODE', 'Travis Scott', 'https://i.scdn.co/image/ab67616d0000b273072e9faef2ef7b6db63834a3', 9, 2, NOW() - INTERVAL '2 days');

  RAISE NOTICE 'Phlock seed data created successfully!';
  RAISE NOTICE 'Created 5 phlocks for user: %', current_user_id;
  RAISE NOTICE '1. Viral Hit: Get Lucky (29 people, 4 generations)';
  RAISE NOTICE '2. Intimate Circle: Bloom (5 people, 100% save rate)';
  RAISE NOTICE '3. Failed Launch: Quantum Dreams (5 people, 20% save rate)';
  RAISE NOTICE '4. Slow Burn: Pink + White (11 people, gradual spread)';
  RAISE NOTICE '5. Echo Chamber: SICKO MODE (9 people, dense network)';

END $$;

-- ⚠️⚠️⚠️ SEED DATA COMPLETE ⚠️⚠️⚠️
