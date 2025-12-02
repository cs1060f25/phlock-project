-- SEED SCRIPT: Requested Users & Songs for @woon
-- Run this in the Supabase SQL Editor

DO $$
DECLARE
    -- 🎯 CONFIGURATION
    target_username text := 'woon'; -- The username to add these friends to
    today_date date := CURRENT_DATE; -- Always use today's date
    
    -- 👤 USER IDs (Fixed UUIDs for consistency)
    current_user_id uuid;
    alex_id uuid := 'a1111111-1111-1111-1111-111111111111';
    brittany_id uuid := 'b2222222-2222-2222-2222-222222222222';
    cam_id uuid := 'c3333333-3333-3333-3333-333333333333';
    daniel_id uuid := 'd4444444-4444-4444-4444-444444444444';
    emily_id uuid := 'e5555555-5555-5555-5555-555555555555';

BEGIN
    -- 1. 🕵️ FIND TARGET USER
    SELECT id INTO current_user_id 
    FROM users 
    WHERE username = target_username 
       OR display_name ILIKE target_username || '%' 
    LIMIT 1;

    IF current_user_id IS NULL THEN
        RAISE EXCEPTION '❌ User "%" not found! Please check the target_username variable at the top of the script.', target_username;
    END IF;

    RAISE NOTICE '✅ Found user: % (ID: %)', target_username, current_user_id;

    -- 2. 👥 UPSERT USERS
    RAISE NOTICE 'Creating/Updating 5 users...';
    
    INSERT INTO users (id, display_name, username, platform_type, daily_song_streak, phlock_count)
    VALUES 
        (alex_id, 'Alex', 'alex', 'spotify', 5, 3),
        (brittany_id, 'Brittany', 'brittany', 'spotify', 12, 7),
        (cam_id, 'Cam', 'cam', 'spotify', 3, 2),
        (daniel_id, 'Daniel', 'daniel', 'spotify', 8, 5),
        (emily_id, 'Emily', 'emily', 'spotify', 21, 10)
    ON CONFLICT (id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        username = EXCLUDED.username,
        platform_type = EXCLUDED.platform_type;

    -- 3. 🎵 UPSERT DAILY SONGS (SHARES)
    RAISE NOTICE 'Setting daily songs for %...', today_date;

    -- Delete existing shares for these users on this date to avoid duplicates/conflicts
    DELETE FROM shares 
    WHERE selected_date = today_date 
      AND sender_id IN (alex_id, brittany_id, cam_id, daniel_id, emily_id)
      AND is_daily_song = true;

    INSERT INTO shares (sender_id, recipient_id, track_id, track_name, artist_name, album_art_url, is_daily_song, selected_date, message, status)
    VALUES
        -- Alex: Lost
        (alex_id, alex_id, '3GZD6HmiNUhxXYf8Gch723', 'Lost', 'Frank Ocean', 'https://i.scdn.co/image/ab67616d0000b2737aede4855f6d0d738012e2e5', true, today_date, 'this song never gets old', 'sent'),
        
        -- Brittany: Espresso
        (brittany_id, brittany_id, '2qSkIjg1o9h3YT9RAgYN75', 'Espresso', 'Sabrina Carpenter', 'https://i.scdn.co/image/ab67616d0000b273659cd4673230913b3918e0d5', true, today_date, 'summer vibes', 'sent'),
        
        -- Cam: Starships
        (cam_id, cam_id, '1oHNvJVbFkexQc0BpQp7Y4', 'Starships', 'Nicki Minaj', 'https://i.scdn.co/image/ab67616d0000b27385235715597dcd07bb9e0f84', true, today_date, NULL, 'sent'),
        
        -- Daniel: Sure Thing
        (daniel_id, daniel_id, '0JXXNGljqupsJaZsgSbMZV', 'Sure Thing', 'Miguel', 'https://i.scdn.co/image/ab67616d0000b273d5a8395b0d80b8c48a5d851c', true, today_date, 'classic', 'sent'),
        
        -- Emily: Good Days
        (emily_id, emily_id, '7vgTNTaEz3CsBZ1N4YQalM', 'Good Days', 'SZA', 'https://i.scdn.co/image/ab67616d0000b2730c64e752dec4c08362cc4a88', true, today_date, 'good days only', 'sent');

    -- 4. 🤝 UPSERT FOLLOWS (Add to Phlock)
    RAISE NOTICE 'Adding users to %''s phlock...', target_username;

    -- Ensure current user follows them and they are in the phlock
    INSERT INTO follows (follower_id, following_id, is_in_phlock, phlock_position, created_at, phlock_added_at)
    VALUES
        (current_user_id, alex_id, true, 1, NOW(), NOW()),
        (current_user_id, brittany_id, true, 2, NOW(), NOW()),
        (current_user_id, cam_id, true, 3, NOW(), NOW()),
        (current_user_id, daniel_id, true, 4, NOW(), NOW()),
        (current_user_id, emily_id, true, 5, NOW(), NOW())
    ON CONFLICT (follower_id, following_id) DO UPDATE SET
        is_in_phlock = true,
        phlock_position = EXCLUDED.phlock_position,
        phlock_added_at = NOW();

    -- Also make them follow the current user back (optional, but good for "friends" logic if any remains)
    INSERT INTO follows (follower_id, following_id, is_in_phlock, created_at)
    VALUES
        (alex_id, current_user_id, false, NOW()),
        (brittany_id, current_user_id, false, NOW()),
        (cam_id, current_user_id, false, NOW()),
        (daniel_id, current_user_id, false, NOW()),
        (emily_id, current_user_id, false, NOW())
    ON CONFLICT (follower_id, following_id) DO NOTHING;

    -- Update counts (using the trigger logic if it exists, but manual update to be safe)
    -- The trigger `update_follow_counts` should handle this if it's active.
    
    RAISE NOTICE '✅ SUCCESS! Added 5 users to your phlock with songs for %.', today_date;

END $$;
