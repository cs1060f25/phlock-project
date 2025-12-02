-- Demo phlock users for testing layout alternatives
-- Run in Supabase Dashboard > SQL Editor

-- Step 1: Create/update 5 demo users
INSERT INTO users (id, display_name, username, platform_type, daily_song_streak, phlock_count, created_at, updated_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'Alex', 'alex', 'spotify', 5, 3, NOW(), NOW()),
  ('b2222222-2222-2222-2222-222222222222', 'Brittany', 'brittany', 'spotify', 21, 7, NOW(), NOW()),
  ('c3333333-3333-3333-3333-333333333333', 'Cam', 'cam', 'spotify', 3, 2, NOW(), NOW()),
  ('d4444444-4444-4444-4444-444444444444', 'Daniel', 'daniel', 'spotify', 8, 5, NOW(), NOW()),
  ('e5555555-5555-5555-5555-555555555555', 'Emily', 'emily', 'spotify', 12, 10, NOW(), NOW())
ON CONFLICT (id) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  username = EXCLUDED.username,
  platform_type = EXCLUDED.platform_type,
  daily_song_streak = EXCLUDED.daily_song_streak,
  phlock_count = EXCLUDED.phlock_count,
  updated_at = NOW();

-- Step 2: Delete any existing daily songs for these demo users today
DELETE FROM shares
WHERE sender_id IN (
  'a1111111-1111-1111-1111-111111111111',
  'b2222222-2222-2222-2222-222222222222',
  'c3333333-3333-3333-3333-333333333333',
  'd4444444-4444-4444-4444-444444444444',
  'e5555555-5555-5555-5555-555555555555'
)
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Step 3: Create daily songs (shares) for each user
-- Note: recipient_id = sender_id for daily songs (self-share pattern)
-- Note: status is required
INSERT INTO shares (
  id, sender_id, recipient_id, track_id, track_name, artist_name, album_art_url,
  preview_url, is_daily_song, selected_date, message, status, created_at
)
VALUES
  -- Alex: Bad (2012 Remaster) - Michael Jackson
  (
    'f1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    '2gSNBigeWMVtY3QBIvPAEc',
    'Bad - 2012 Remaster',
    'Michael Jackson',
    'https://i.scdn.co/image/ab67616d0000b2732e0cd1330748a5b7764dd562',
    NULL,
    true,
    CURRENT_DATE,
    'the king of pop',
    'sent',
    NOW() - INTERVAL '3 hours'
  ),
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
  (
    'f5555555-5555-5555-5555-555555555555',
    'e5555555-5555-5555-5555-555555555555',
    'e5555555-5555-5555-5555-555555555555',
    '7vgTNTaEz3CsBZ1N4YQalM',
    'Good Days',
    'SZA',
    'https://i.scdn.co/image/ab67616d0000b27304257b29be46a894e651a1a3',
    NULL,
    true,
    CURRENT_DATE,
    'good days only',
    'sent',
    NOW() - INTERVAL '30 minutes'
  );

-- Step 4: Verify the shares
SELECT 'Demo daily songs created for today:' as status;
SELECT s.track_name, s.artist_name, u.username as from_user, s.selected_date
FROM shares s
JOIN users u ON s.sender_id = u.id
WHERE s.sender_id IN (
  'a1111111-1111-1111-1111-111111111111',
  'b2222222-2222-2222-2222-222222222222',
  'c3333333-3333-3333-3333-333333333333',
  'd4444444-4444-4444-4444-444444444444',
  'e5555555-5555-5555-5555-555555555555'
)
AND s.is_daily_song = true
AND s.selected_date = CURRENT_DATE;
