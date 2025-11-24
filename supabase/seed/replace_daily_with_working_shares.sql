-- Replace today's problematic daily songs (Blinding Lights, Peaches) with
-- working tracks from existing shares that already have preview URLs.
-- This maps Blinding Lights -> "Won't Live Here" and Peaches -> "Therefore I Am".
-- Run in Supabase SQL Editor.

WITH working_source AS (
    SELECT DISTINCT ON (normalized_name)
        normalized_name,
        track_id,
        track_name,
        artist_name,
        album_art_url,
        preview_url
    FROM (
        SELECT
            LOWER(track_name) AS normalized_name,
            track_id,
            track_name,
            artist_name,
            album_art_url,
            preview_url,
            created_at
        FROM shares
        WHERE is_daily_song = false
          AND preview_url IS NOT NULL
          AND preview_url != ''
          AND (track_name ILIKE '%won''t live here%' OR track_name ILIKE '%therefore i am%')
    ) s
    ORDER BY normalized_name, created_at DESC
),
replacements AS (
    SELECT
        CASE
            WHEN normalized_name LIKE '%won''t live here%' THEN 'BLINDING_LIGHTS'
            ELSE 'PEACHES'
        END AS slot,
        track_id,
        track_name,
        artist_name,
        album_art_url,
        preview_url
    FROM working_source
),
updated AS (
    UPDATE shares AS daily
    SET
        track_id = r.track_id,
        track_name = r.track_name,
        artist_name = r.artist_name,
        album_art_url = COALESCE(r.album_art_url, daily.album_art_url),
        preview_url = r.preview_url,
        updated_at = NOW()
    FROM replacements r
    WHERE daily.is_daily_song = true
      AND daily.selected_date = CURRENT_DATE
      AND (
          (r.slot = 'BLINDING_LIGHTS' AND (daily.track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b' OR daily.track_name ILIKE 'Blinding Lights%'))
          OR (r.slot = 'PEACHES' AND (daily.track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI' OR daily.track_name ILIKE 'Peaches%'))
      )
    RETURNING
        daily.id AS daily_id,
        daily.sender_id,
        r.slot AS replaced_slot,
        r.track_name AS new_track_name,
        r.artist_name AS new_artist_name,
        r.track_id AS new_track_id,
        r.preview_url AS new_preview_url
)
SELECT * FROM updated;
