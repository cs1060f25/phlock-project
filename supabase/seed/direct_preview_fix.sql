-- Direct fix: Update daily songs with the exact same preview URLs that are working in your shares
-- Run this in Supabase SQL Editor

-- First, let's find what preview URLs are actually working for these tracks in your shares
SELECT
    track_name,
    artist_name,
    track_id,
    preview_url,
    is_daily_song,
    created_at
FROM shares
WHERE (
    track_name ILIKE '%blinding%lights%' OR
    track_name ILIKE '%peaches%' OR
    track_id IN (
        'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
        'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
    )
)
ORDER BY is_daily_song DESC, created_at DESC
LIMIT 20;

-- Now copy the working preview URL from any regular share to the daily song
-- For Blinding Lights
UPDATE shares AS daily
SET preview_url = (
    SELECT preview_url
    FROM shares
    WHERE track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    LIMIT 1
)
WHERE daily.track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE;

-- For Peaches
UPDATE shares AS daily
SET preview_url = (
    SELECT preview_url
    FROM shares
    WHERE track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    LIMIT 1
)
WHERE daily.track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE;

-- Alternative: If track_ids don't match exactly, use track name matching
UPDATE shares AS daily
SET preview_url = (
    SELECT preview_url
    FROM shares
    WHERE LOWER(track_name) = LOWER(daily.track_name)
    AND LOWER(artist_name) = LOWER(daily.artist_name)
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    LIMIT 1
)
WHERE daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND daily.track_name IN ('Blinding Lights', 'Peaches')
AND (daily.preview_url IS NULL OR daily.preview_url = '');

-- Verify the final state
SELECT
    track_name,
    artist_name,
    preview_url,
    LENGTH(preview_url) as url_length
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;