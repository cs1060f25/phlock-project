-- Ensure that at least three phlock members have a daily song selected/sent for today.
-- Uses three known-good tracks with working previews (Little Bit More, Won't Live Here, Mr. Brightside).
-- Run in Supabase SQL Editor.

DO $$
DECLARE
    test_user_id UUID;
    friend_ids UUID[];
    today DATE := CURRENT_DATE;
BEGIN
    -- Locate the test user (falls back to any user if the known auth_user_id is missing)
    SELECT id INTO test_user_id
    FROM users
    WHERE auth_user_id = '45db2427-9b99-49bf-a334-895ec91b038c'::uuid
    LIMIT 1;

    IF test_user_id IS NULL THEN
        SELECT id INTO test_user_id FROM users LIMIT 1;
    END IF;

    -- Collect up to five phlock members in position order, otherwise any accepted friends
    SELECT array_agg(user_id_2 ORDER BY position NULLS LAST, created_at)
    INTO friend_ids
    FROM friendships
    WHERE user_id_1 = test_user_id
      AND status = 'accepted';

    -- Safety: ensure we have at least three friends
    IF array_length(friend_ids, 1) < 3 THEN
        RAISE NOTICE 'Not enough friends found to seed daily songs (found: %)', array_length(friend_ids, 1);
        RETURN;
    END IF;

    -- Clear any existing daily songs for today for these friends
    DELETE FROM shares
    WHERE is_daily_song = true
      AND selected_date = today
      AND sender_id = ANY(friend_ids);

    -- Insert three daily songs with working previews
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES
    (
        gen_random_uuid(),
        friend_ids[1], friend_ids[1],
        'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp', -- Mr. Brightside
        'Mr. Brightside',
        'The Killers',
        'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d',
        'https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    ),
    (
        gen_random_uuid(),
        friend_ids[2], friend_ids[2],
        'spotify:track:6ZJ0zTlIuVMix4xFLQM9mU', -- Little Bit More
        'Little Bit More',
        'Mk.gee',
        'https://i.scdn.co/image/ab67616d0000b273038b1c2017f14c805cf5b7e9',
        'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/5b/00/a8/5b00a84d-395e-1abd-eb50-fd1e17bb5fb0/mzaf_9395982198996741934.plus.aac.p.m4a',
        'sent',
        true,
        today,
        NOW() + interval '1 second',
        NOW() + interval '1 second'
    ),
    (
        gen_random_uuid(),
        friend_ids[3], friend_ids[3],
        'spotify:track:0GS18kfRx31TtYkLhbqrrG', -- Won't Live Here
        'Won''t Live Here',
        'Daniel Caesar',
        'https://i.scdn.co/image/ab67616d0000b27335e2dfd4e0988943a5e93095',
        'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/60/83/57/608357fd-7c28-45ba-8c29-d6368aa839ab/mzaf_9574401825193793219.plus.aac.p.m4a',
        'sent',
        true,
        today,
        NOW() + interval '2 seconds',
        NOW() + interval '2 seconds'
    );

    RAISE NOTICE 'Seeded daily songs for friends: %, %, %', friend_ids[1], friend_ids[2], friend_ids[3];
END $$;

-- Verify: show today’s daily songs
SELECT
    sender_id,
    track_name,
    artist_name,
    status,
    selected_date,
    CASE
        WHEN preview_url IS NULL OR preview_url = '' THEN '❌ Missing preview'
        ELSE '✅ Has preview'
    END AS preview_status
FROM shares
WHERE is_daily_song = true
  AND selected_date = CURRENT_DATE
ORDER BY created_at;
