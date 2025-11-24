-- Replace Tyler Washington's daily song with "Yamaha" by Dijon for today.
-- Drops any existing daily rows from Tyler for today and inserts fresh metadata
-- with a working Apple preview URL and correct artwork (avoids stale data from prior updates).
-- Run in Supabase SQL Editor.

WITH tyler AS (
    SELECT id
    FROM users
    WHERE display_name ILIKE 'Tyler Washington'
       OR username ILIKE 'tyler%'
    LIMIT 1
),
deleted AS (
    DELETE FROM shares
    USING tyler
    WHERE shares.sender_id = tyler.id
      AND shares.is_daily_song = true
      AND shares.selected_date = CURRENT_DATE
    RETURNING shares.id
),
inserted AS (
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, status, is_daily_song, selected_date,
        created_at, updated_at
    )
    SELECT
        gen_random_uuid(),
        tyler.id,
        tyler.id,
        'spotify:track:6qR5YGunNSASaabs4kJB9V',
        'Yamaha',
        'Dijon',
        'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/b0/0b/d3/b00bd346-7b14-da61-28b0-94d2ea03f58e/093624826873.jpg/1000x1000bb.jpg',
        'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/05/92/d7/0592d726-11d2-eb7e-9932-30b0270d05e9/mzaf_1654366494235396194.plus.aac.p.m4a',
        'sent',
        true,
        CURRENT_DATE,
        NOW(),
        NOW()
    FROM tyler
    RETURNING id, sender_id, track_name, artist_name, preview_url, album_art_url
)
SELECT * FROM inserted;
