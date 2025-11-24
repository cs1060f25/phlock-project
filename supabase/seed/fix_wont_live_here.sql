-- Specific fix for "Won't Live Here" by Daniel Caesar
-- Find and copy the working preview URL from existing shares

-- First, let's find ALL instances of this track in shares to see what we have
SELECT
    track_name,
    artist_name,
    track_id,
    preview_url,
    is_daily_song,
    created_at,
    CASE
        WHEN preview_url IS NULL THEN 'NULL'
        WHEN preview_url = '' THEN 'EMPTY'
        ELSE 'Has URL: ' || LEFT(preview_url, 50) || '...'
    END as preview_status
FROM shares
WHERE (
    track_name ILIKE '%won%t%live%here%' OR
    track_name = 'Won''t Live Here' OR
    track_name = 'Wont Live Here'
)
AND artist_name ILIKE '%daniel%caesar%'
ORDER BY is_daily_song DESC, created_at DESC;

-- Find the working preview URL for Won't Live Here
WITH working_preview AS (
    SELECT
        preview_url,
        track_id
    FROM shares
    WHERE (
        track_name ILIKE '%won%t%live%here%' OR
        track_name = 'Won''t Live Here' OR
        track_name = 'Wont Live Here'
    )
    AND artist_name ILIKE '%daniel%caesar%'
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    ORDER BY created_at DESC
    LIMIT 1
)
SELECT
    'Found working preview for Won''t Live Here:' as message,
    preview_url
FROM working_preview;

-- Update the daily song with the working preview URL
UPDATE shares
SET preview_url = (
    SELECT preview_url
    FROM shares
    WHERE (
        track_name ILIKE '%won%t%live%here%' OR
        track_name = 'Won''t Live Here' OR
        track_name = 'Wont Live Here'
    )
    AND artist_name ILIKE '%daniel%caesar%'
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    ORDER BY created_at DESC
    LIMIT 1
)
WHERE track_name = 'Won''t Live Here'
AND artist_name = 'Daniel Caesar'
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Alternative: If the track_id is consistent, use that
UPDATE shares AS daily
SET preview_url = (
    SELECT preview_url
    FROM shares AS source
    WHERE source.track_id = daily.track_id
    AND source.is_daily_song = false
    AND source.preview_url IS NOT NULL
    AND source.preview_url != ''
    ORDER BY source.created_at DESC
    LIMIT 1
)
WHERE daily.track_name = 'Won''t Live Here'
AND daily.artist_name = 'Daniel Caesar'
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND daily.track_id IS NOT NULL;

-- Final check - verify all daily songs now have preview URLs
SELECT
    track_name,
    artist_name,
    preview_url,
    CASE
        WHEN preview_url IS NULL THEN '❌ Still NULL'
        WHEN preview_url = '' THEN '❌ Still EMPTY'
        WHEN LENGTH(preview_url) > 0 THEN '✅ Fixed! (' || LENGTH(preview_url) || ' chars)'
        ELSE '❓ Unknown'
    END as status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;

-- Debug: Show all Daniel Caesar tracks in the database
SELECT
    'All Daniel Caesar tracks:' as debug_info,
    track_name,
    track_id,
    LENGTH(preview_url) as preview_length,
    is_daily_song,
    created_at
FROM shares
WHERE artist_name ILIKE '%daniel%caesar%'
ORDER BY created_at DESC
LIMIT 10;