-- Seed @woon's phlock with demo users and their daily songs
-- Run this in Supabase Dashboard > SQL Editor

-- @woon's user ID
-- woon: 7d1ca118-b5b1-4a73-a6ed-850dd22575dc

-- Demo user IDs:
-- alex: a1111111-1111-1111-1111-111111111111
-- brittany: b2222222-2222-2222-2222-222222222222
-- cam: c3333333-3333-3333-3333-333333333333
-- daniel: d4444444-4444-4444-4444-444444444444
-- emily: e5555555-5555-5555-5555-555555555555
-- test2: cb612cb3-c426-495e-836c-4de48a1b1a07

-- Step 1: Clear existing follows for woon
DELETE FROM follows WHERE follower_id = '7d1ca118-b5b1-4a73-a6ed-850dd22575dc';

-- Step 2: Add demo users to woon's phlock
INSERT INTO follows (follower_id, following_id, is_in_phlock, phlock_position, created_at)
VALUES
  ('7d1ca118-b5b1-4a73-a6ed-850dd22575dc', 'b2222222-2222-2222-2222-222222222222', true, 1, NOW()), -- Brittany
  ('7d1ca118-b5b1-4a73-a6ed-850dd22575dc', 'c3333333-3333-3333-3333-333333333333', true, 2, NOW()), -- Cam
  ('7d1ca118-b5b1-4a73-a6ed-850dd22575dc', 'e5555555-5555-5555-5555-555555555555', true, 3, NOW()), -- Emily
  ('7d1ca118-b5b1-4a73-a6ed-850dd22575dc', 'd4444444-4444-4444-4444-444444444444', true, 4, NOW()), -- Daniel
  ('7d1ca118-b5b1-4a73-a6ed-850dd22575dc', 'cb612cb3-c426-495e-836c-4de48a1b1a07', true, 5, NOW())  -- test2
ON CONFLICT (follower_id, following_id) DO UPDATE SET
  is_in_phlock = true,
  phlock_position = EXCLUDED.phlock_position;

-- Step 3: Clear existing daily songs for demo users today
DELETE FROM shares
WHERE sender_id IN (
  'a1111111-1111-1111-1111-111111111111',
  'b2222222-2222-2222-2222-222222222222',
  'c3333333-3333-3333-3333-333333333333',
  'd4444444-4444-4444-4444-444444444444',
  'e5555555-5555-5555-5555-555555555555',
  'cb612cb3-c426-495e-836c-4de48a1b1a07'
)
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Step 4: Create daily songs for demo users
INSERT INTO shares (
  id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url,
  preview_url, is_daily_song, selected_date, message, status, created_at
)
VALUES
  -- Brittany: Lost - Frank Ocean
  (
    'f2222222-2222-2222-2222-222222222222',
    'b2222222-2222-2222-2222-222222222222',
    'b2222222-2222-2222-2222-222222222222',
    '3GZD6HmiNUhxXYf8Gch723',
    'Lost',
    'Frank Ocean',
    'https://i.scdn.co/image/ab67616d0000b2737aede4855f6d0d738012e2e5',
    NULL,
    true,
    CURRENT_DATE,
    'channel orange vibes',
    'sent',
    NOW() - INTERVAL '2 hours'
  ),
  -- Cam: White Teeth - Ryan Beatty
  (
    'f3333333-3333-3333-3333-333333333333',
    'c3333333-3333-3333-3333-333333333333',
    'c3333333-3333-3333-3333-333333333333',
    '3Gqagi4hGvcHyoWznBi4q3',
    'White Teeth',
    'Ryan Beatty',
    'https://i.scdn.co/image/ab67616d0000b27389bcf0e9d8e14d33dea77acf',
    NULL,
    true,
    CURRENT_DATE,
    'so dreamy',
    'sent',
    NOW() - INTERVAL '5 hours'
  ),
  -- Emily: Good Days by SZA (CORRECT Spotify ID: 3YJJjQPAbDT7mGpX3WtQ9A)
  (
    'f5555555-5555-5555-5555-555555555555',
    'e5555555-5555-5555-5555-555555555555',
    'e5555555-5555-5555-5555-555555555555',
    '3YJJjQPAbDT7mGpX3WtQ9A',
    'Good Days',
    'SZA',
    'https://i.scdn.co/image/ab67616d0000b27304257b29be46a894e651a1a3',
    NULL,
    true,
    CURRENT_DATE,
    'good days only',
    'sent',
    NOW() - INTERVAL '30 minutes'
  ),
  -- Daniel: Real Life - The Weeknd
  (
    'f4444444-4444-4444-4444-444444444444',
    'd4444444-4444-4444-4444-444444444444',
    'd4444444-4444-4444-4444-444444444444',
    '03j354P848KtNU2FVSwkDG',
    'Real Life',
    'The Weeknd',
    'https://i.scdn.co/image/ab67616d0000b2737fcead687e99583072cc217b',
    NULL,
    true,
    CURRENT_DATE,
    'beauty behind the madness',
    'sent',
    NOW() - INTERVAL '1 hour'
  ),
  -- test2: Ghost Town by Kanye West (CORRECT Spotify ID: 7vgTNTaEz3CsBZ1N4YQalM from "ye" album)
  (
    'f6666666-6666-6666-6666-666666666666',
    'cb612cb3-c426-495e-836c-4de48a1b1a07',
    'cb612cb3-c426-495e-836c-4de48a1b1a07',
    '7vgTNTaEz3CsBZ1N4YQalM',
    'Ghost Town',
    'Kanye West',
    'https://i.scdn.co/image/ab67616d0000b2730cd942c1a864afa4e92d04f2',
    NULL,
    true,
    CURRENT_DATE,
    'ye vibes',
    'sent',
    NOW() - INTERVAL '4 hours'
  );

-- Step 5: Verify
SELECT 'Woon phlock members:' as info;
SELECT f.phlock_position, u.username, u.display_name
FROM follows f
JOIN users u ON f.following_id = u.id
WHERE f.follower_id = '7d1ca118-b5b1-4a73-a6ed-850dd22575dc'
AND f.is_in_phlock = true
ORDER BY f.phlock_position;

SELECT 'Daily songs for today:' as info;
SELECT s.track_name, s.artist_name, u.username as from_user
FROM shares s
JOIN users u ON s.sender_id = u.id
WHERE s.is_daily_song = true
AND s.selected_date = CURRENT_DATE;
