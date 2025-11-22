-- Fix daily playlist setup for user B1660762-C5CA-4389-9461-72D505E52EBB
-- This script ensures the columns exist and adds test data

-- Step 1: Ensure columns exist
ALTER TABLE friendships
ADD COLUMN IF NOT EXISTS position INT CHECK (position >= 1 AND position <= 5),
ADD COLUMN IF NOT EXISTS is_phlock_member BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_swapped_at TIMESTAMPTZ;

ALTER TABLE shares
ADD COLUMN IF NOT EXISTS is_daily_song BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS selected_date DATE,
ADD COLUMN IF NOT EXISTS preview_url TEXT;

-- Step 2: Clear existing phlock members for the test user
UPDATE friendships
SET is_phlock_member = false, position = NULL
WHERE (user_id_1 = 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid
    OR user_id_2 = 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid);

-- Step 3: Add 3 friends as phlock members with positions
DO $$
DECLARE
    test_user_id UUID := 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid;
    friend1_id UUID;
    friend2_id UUID;
    friend3_id UUID;
    today_date DATE := CURRENT_DATE;
BEGIN
    -- Get friend IDs (using the friends you have)
    SELECT user_id_2 INTO friend1_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND status = 'accepted'
    LIMIT 1 OFFSET 0;

    SELECT user_id_2 INTO friend2_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND status = 'accepted'
    LIMIT 1 OFFSET 1;

    SELECT user_id_2 INTO friend3_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND status = 'accepted'
    LIMIT 1 OFFSET 2;

    -- Update friendships to make them phlock members
    IF friend1_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 1, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = friend1_id)
            OR (user_id_1 = friend1_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        -- Delete any existing daily song for today
        DELETE FROM shares
        WHERE sender_id = friend1_id
        AND is_daily_song = true
        AND selected_date = today_date;

        -- Add friend1's daily song
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend1_id,
            friend1_id,
            'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
            'Mr. Brightside',
            'The Killers',
            'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d',
            'https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba',
            'sent',
            true,
            today_date,
            NOW()
        );
        RAISE NOTICE 'Added friend1 (%) at position 1', friend1_id;
    END IF;

    IF friend2_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 2, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = friend2_id)
            OR (user_id_1 = friend2_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        DELETE FROM shares
        WHERE sender_id = friend2_id
        AND is_daily_song = true
        AND selected_date = today_date;

        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend2_id,
            friend2_id,
            'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
            'Blinding Lights',
            'The Weeknd',
            'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
            'https://p.scdn.co/mp3-preview/e9f1e0e7e3c6c1277f29c1df52c5af5b6e26a55c',
            'sent',
            true,
            today_date,
            NOW()
        );
        RAISE NOTICE 'Added friend2 (%) at position 2', friend2_id;
    END IF;

    IF friend3_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 3, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = friend3_id)
            OR (user_id_1 = friend3_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        DELETE FROM shares
        WHERE sender_id = friend3_id
        AND is_daily_song = true
        AND selected_date = today_date;

        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend3_id,
            friend3_id,
            'spotify:track:4iJyoBOLtHqaGxP12qzhQI',
            'Peaches',
            'Justin Bieber',
            'https://i.scdn.co/image/ab67616d0000b273e6f407c7f3a0ec98845e4431',
            'https://p.scdn.co/mp3-preview/8cc84b3df71da3f32f1b66ca83cd985e14f9c759',
            'sent',
            true,
            today_date,
            NOW()
        );
        RAISE NOTICE 'Added friend3 (%) at position 3', friend3_id;
    END IF;

    RAISE NOTICE 'Setup complete!';
END $$;

-- Verify the setup
SELECT
    f.position,
    u.display_name,
    u.id as user_id,
    s.track_name,
    s.artist_name,
    s.selected_date
FROM friendships f
JOIN users u ON (
    CASE
        WHEN f.user_id_1 = 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid
        THEN f.user_id_2
        ELSE f.user_id_1
    END = u.id
)
LEFT JOIN shares s ON s.sender_id = u.id
    AND s.is_daily_song = true
    AND s.selected_date = CURRENT_DATE
WHERE f.is_phlock_member = true
    AND (f.user_id_1 = 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid
        OR f.user_id_2 = 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid)
ORDER BY f.position;