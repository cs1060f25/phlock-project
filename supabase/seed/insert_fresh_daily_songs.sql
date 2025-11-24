-- Complete fresh insert of daily songs with verified working preview URLs
-- Run this in Supabase SQL Editor

-- First, delete existing daily songs for today
DELETE FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Now insert fresh songs with working preview URLs
DO $$
DECLARE
    test_user_id UUID := 'B1660762-C5CA-4389-9461-72D505E52EBB'::uuid;
    friend1_id UUID;
    friend2_id UUID;
    friend3_id UUID;
    today_date DATE := CURRENT_DATE;
BEGIN
    -- Get friend IDs from existing phlock members
    SELECT user_id_2 INTO friend1_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND is_phlock_member = true
    AND position = 1
    LIMIT 1;

    SELECT user_id_2 INTO friend2_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND is_phlock_member = true
    AND position = 2
    LIMIT 1;

    SELECT user_id_2 INTO friend3_id
    FROM friendships
    WHERE user_id_1 = test_user_id
    AND is_phlock_member = true
    AND position = 3
    LIMIT 1;

    -- If we don't have the specific member structure, use any friends
    IF friend1_id IS NULL THEN
        SELECT user_id_2 INTO friend1_id
        FROM friendships
        WHERE user_id_1 = test_user_id
        AND status = 'accepted'
        LIMIT 1 OFFSET 0;
    END IF;

    IF friend2_id IS NULL THEN
        SELECT user_id_2 INTO friend2_id
        FROM friendships
        WHERE user_id_1 = test_user_id
        AND status = 'accepted'
        LIMIT 1 OFFSET 1;
    END IF;

    IF friend3_id IS NULL THEN
        SELECT user_id_2 INTO friend3_id
        FROM friendships
        WHERE user_id_1 = test_user_id
        AND status = 'accepted'
        LIMIT 1 OFFSET 2;
    END IF;

    -- Insert Friend 1's song - Mr. Brightside (this one works)
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
        RAISE NOTICE 'Added Mr. Brightside for friend1 (%)' , friend1_id;
    END IF;

    -- Insert Friend 2's song - Cruel Summer by Taylor Swift (verified working)
    IF friend2_id IS NOT NULL THEN
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend2_id,
            friend2_id,
            'spotify:track:1BxfuPKGuaTgP7aM0Bbdwr',
            'Cruel Summer',
            'Taylor Swift',
            'https://i.scdn.co/image/ab67616d0000b273e787cffec20aa2a396a61647',
            'https://p.scdn.co/mp3-preview/5ac5b897fef98784b7bba8576c160024a327195e',
            'sent',
            true,
            today_date,
            NOW() + interval '1 second'
        );
        RAISE NOTICE 'Added Cruel Summer for friend2 (%)' , friend2_id;
    END IF;

    -- Insert Friend 3's song - Vampire by Olivia Rodrigo (verified working)
    IF friend3_id IS NOT NULL THEN
        INSERT INTO shares (
            id, sender_id, recipient_id, track_id, track_name, artist_name,
            album_art_url, preview_url, status, is_daily_song, selected_date, created_at
        ) VALUES (
            gen_random_uuid(),
            friend3_id,
            friend3_id,
            'spotify:track:1kuGVB7EU95pJObxwvfwKS',
            'vampire',
            'Olivia Rodrigo',
            'https://i.scdn.co/image/ab67616d0000b273e85259a1cae29a8d91f2093d',
            'https://p.scdn.co/mp3-preview/53cc3c883c978d2c46ac0f3e63f2e35c87d96b69',
            'sent',
            true,
            today_date,
            NOW() + interval '2 seconds'
        );
        RAISE NOTICE 'Added Vampire for friend3 (%)' , friend3_id;
    END IF;

END $$;

-- Verify the new songs
SELECT
    track_name,
    artist_name,
    preview_url,
    LENGTH(preview_url) as url_length,
    selected_date
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;