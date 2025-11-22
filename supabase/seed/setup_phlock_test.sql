-- Quick setup for testing daily playlist
-- Run this in Supabase SQL Editor

-- Step 1: Add columns if they don't exist
ALTER TABLE friendships
ADD COLUMN IF NOT EXISTS position INT CHECK (position >= 1 AND position <= 5),
ADD COLUMN IF NOT EXISTS is_phlock_member BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_swapped_at TIMESTAMPTZ;

ALTER TABLE shares
ADD COLUMN IF NOT EXISTS is_daily_song BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS selected_date DATE,
ADD COLUMN IF NOT EXISTS preview_url TEXT;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS phlock_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS daily_song_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_daily_song_date DATE;

-- Step 2: Set up test user and phlock members
DO $$
DECLARE
    test_user_id UUID;
    emma_id UUID;
    marcus_id UUID;
    sofia_id UUID;
BEGIN
    -- Get test user (you - the one who's logged in)
    -- Replace this with your actual user ID if different
    SELECT id INTO test_user_id FROM users
    WHERE auth_user_id = auth.uid()
    LIMIT 1;

    IF test_user_id IS NULL THEN
        RAISE NOTICE 'No user found for current auth user';
        RETURN;
    END IF;

    -- Get friend IDs
    SELECT id INTO emma_id FROM users WHERE display_name = 'Emma' LIMIT 1;
    SELECT id INTO marcus_id FROM users WHERE display_name = 'Marcus' LIMIT 1;
    SELECT id INTO sofia_id FROM users WHERE display_name = 'Sofia' LIMIT 1;

    -- Clear existing phlock members
    UPDATE friendships
    SET is_phlock_member = false, position = NULL
    WHERE (user_id_1 = test_user_id OR user_id_2 = test_user_id);

    -- Add Emma as position 1
    IF emma_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 1, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = emma_id)
            OR (user_id_1 = emma_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        -- Add Emma's daily song
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(), emma_id, emma_id,
            'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
            'Mr. Brightside', 'The Killers',
            'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d',
            'https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba',
            'sent', true, CURRENT_DATE, NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    -- Add Marcus as position 2
    IF marcus_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 2, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = marcus_id)
            OR (user_id_1 = marcus_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        -- Add Marcus's daily song
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(), marcus_id, marcus_id,
            'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
            'Blinding Lights', 'The Weeknd',
            'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
            'https://p.scdn.co/mp3-preview/e9f1e0e7e3c6c1277f29c1df52c5af5b6e26a55c',
            'sent', true, CURRENT_DATE, NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    -- Add Sofia as position 3
    IF sofia_id IS NOT NULL THEN
        UPDATE friendships
        SET is_phlock_member = true, position = 3, last_swapped_at = NOW()
        WHERE ((user_id_1 = test_user_id AND user_id_2 = sofia_id)
            OR (user_id_1 = sofia_id AND user_id_2 = test_user_id))
        AND status = 'accepted';

        -- Add Sofia's daily song
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(), sofia_id, sofia_id,
            'spotify:track:4iJyoBOLtHqaGxP12qzhQI',
            'Peaches', 'Justin Bieber',
            'https://i.scdn.co/image/ab67616d0000b273e6f407c7f3a0ec98845e4431',
            'https://p.scdn.co/mp3-preview/8cc84b3df71da3f32f1b66ca83cd985e14f9c759',
            'sent', true, CURRENT_DATE, NOW()
        ) ON CONFLICT DO NOTHING;
    END IF;

    RAISE NOTICE 'Setup complete! Added % phlock members', 3;
END $$;

-- Query to verify setup
SELECT
    f.position,
    u.display_name,
    s.track_name,
    s.artist_name
FROM friendships f
JOIN users u ON (
    CASE
        WHEN f.user_id_1 = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
        THEN f.user_id_2
        ELSE f.user_id_1
    END = u.id
)
LEFT JOIN shares s ON s.sender_id = u.id AND s.is_daily_song = true AND s.selected_date = CURRENT_DATE
WHERE f.is_phlock_member = true
AND (f.user_id_1 = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1)
     OR f.user_id_2 = (SELECT id FROM users WHERE auth_user_id = auth.uid() LIMIT 1))
ORDER BY f.position;