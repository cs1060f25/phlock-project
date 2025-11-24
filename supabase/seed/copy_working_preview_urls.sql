-- Copy working preview URLs from existing shares to daily songs
-- This finds the same tracks in regular shares that have working preview URLs

-- First, let's see what preview URLs exist for these tracks in regular shares
WITH working_previews AS (
    SELECT DISTINCT
        track_id,
        track_name,
        artist_name,
        preview_url,
        album_art_url
    FROM shares
    WHERE preview_url IS NOT NULL
    AND preview_url != ''
    AND is_daily_song = false
    AND track_id IN (
        'spotify:track:0VjIjW4GlUZAMYd2vXMi3b', -- Blinding Lights
        'spotify:track:4iJyoBOLtHqaGxP12qzhQI'  -- Peaches
    )
)
SELECT * FROM working_previews;

-- Now update the daily songs with the working preview URLs from regular shares
UPDATE shares AS daily
SET
    preview_url = working.preview_url,
    album_art_url = COALESCE(daily.album_art_url, working.album_art_url)
FROM (
    SELECT DISTINCT ON (track_id)
        track_id,
        preview_url,
        album_art_url
    FROM shares
    WHERE preview_url IS NOT NULL
    AND preview_url != ''
    AND is_daily_song = false
    ORDER BY track_id, created_at DESC
) AS working
WHERE daily.track_id = working.track_id
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE;

-- Also check for any tracks by name if track_id doesn't match
UPDATE shares AS daily
SET preview_url = working.preview_url
FROM (
    SELECT DISTINCT ON (track_name, artist_name)
        track_name,
        artist_name,
        preview_url
    FROM shares
    WHERE preview_url IS NOT NULL
    AND preview_url != ''
    AND is_daily_song = false
    ORDER BY track_name, artist_name, created_at DESC
) AS working
WHERE daily.track_name = working.track_name
AND daily.artist_name = working.artist_name
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND (daily.preview_url IS NULL OR daily.preview_url = '');

-- Verify the updates
SELECT
    track_name,
    artist_name,
    preview_url,
    CASE
        WHEN preview_url IS NULL THEN '❌ No preview'
        WHEN preview_url = '' THEN '❌ Empty preview'
        ELSE '✅ Has preview'
    END as status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;

-- Show what preview URLs we found from regular shares
SELECT
    'Found in regular shares:' as source,
    track_name,
    artist_name,
    LEFT(preview_url, 50) || '...' as preview_url_start
FROM shares
WHERE track_name IN ('Blinding Lights', 'Peaches')
AND is_daily_song = false
AND preview_url IS NOT NULL
AND preview_url != ''
LIMIT 10;