-- Final fix: Set preview URLs to NULL for tracks without working previews
-- The app will fall back to Apple Music for these
-- Run this in Supabase SQL Editor

-- Set Blinding Lights preview to NULL (will trigger Apple Music fallback)
UPDATE shares
SET preview_url = NULL
WHERE track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
AND is_daily_song = true;

-- Set Peaches preview to NULL (will trigger Apple Music fallback)
UPDATE shares
SET preview_url = NULL
WHERE track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
AND is_daily_song = true;

-- Alternatively, delete all daily songs and recreate with tracks that have no preview
-- so the app uses Apple Music fallback
DELETE FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Insert songs with NULL preview URLs to trigger Apple Music fallback
DO $$
DECLARE
    test_user_id UUID := 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid;
    friend1_id UUID;
    friend2_id UUID;
    friend3_id UUID;
    today_date DATE := CURRENT_DATE;
BEGIN
    -- Get friend IDs
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

    -- Insert with working preview (Mr. Brightside)
    IF friend1_id IS NOT NULL THEN
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
    END IF;

    -- Insert with NULL preview to use Apple Music (Blinding Lights)
    IF friend2_id IS NOT NULL THEN
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
            NULL,  -- NULL will trigger Apple Music fallback
            'sent',
            true,
            today_date,
            NOW() + interval '1 second'
        );
    END IF;

    -- Insert with NULL preview to use Apple Music (Peaches)
    IF friend3_id IS NOT NULL THEN
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend3_id,
            friend3_id,
            'spotify:track:4iJyoBOLtHqaGxP12qzhQI',
            'Peaches (feat. Daniel Caesar & Giveon)',
            'Justin Bieber',
            'https://i.scdn.co/image/ab67616d0000b273e6f407c7f3a0ec98845e4431',
            NULL,  -- NULL will trigger Apple Music fallback
            'sent',
            true,
            today_date,
            NOW() + interval '2 seconds'
        );
    END IF;

    RAISE NOTICE 'Inserted songs - tracks without preview URLs will use Apple Music fallback';
END $$;

-- Verify
SELECT
    track_name,
    artist_name,
    CASE
        WHEN preview_url IS NULL THEN 'Will use Apple Music'
        ELSE 'Has Spotify preview'
    END as preview_status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;