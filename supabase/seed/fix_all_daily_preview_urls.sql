-- Fix ALL daily songs that are missing preview URLs by copying from working shares
-- This will fix Won't Live Here and any other tracks with empty/null preview URLs

-- First, show what daily songs need fixing
SELECT
    track_name,
    artist_name,
    track_id,
    preview_url,
    CASE
        WHEN preview_url IS NULL THEN 'NULL'
        WHEN preview_url = '' THEN 'EMPTY'
        ELSE 'OK'
    END as preview_status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;

-- Update ALL daily songs with missing preview URLs from their working shares
UPDATE shares AS daily
SET preview_url = working.preview_url
FROM (
    -- Find the most recent working preview URL for each track
    SELECT DISTINCT ON (track_id)
        track_id,
        preview_url
    FROM shares
    WHERE preview_url IS NOT NULL
    AND preview_url != ''
    AND is_daily_song = false
    ORDER BY track_id, created_at DESC
) AS working
WHERE daily.track_id = working.track_id
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND (daily.preview_url IS NULL OR daily.preview_url = '');

-- Also try matching by track name and artist for any that didn't match by ID
UPDATE shares AS daily
SET preview_url = working.preview_url
FROM (
    SELECT DISTINCT ON (LOWER(track_name), LOWER(artist_name))
        LOWER(track_name) as track_name_lower,
        LOWER(artist_name) as artist_name_lower,
        preview_url
    FROM shares
    WHERE preview_url IS NOT NULL
    AND preview_url != ''
    AND is_daily_song = false
    ORDER BY LOWER(track_name), LOWER(artist_name), created_at DESC
) AS working
WHERE LOWER(daily.track_name) = working.track_name_lower
AND LOWER(daily.artist_name) = working.artist_name_lower
AND daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND (daily.preview_url IS NULL OR daily.preview_url = '');

-- Special handling for "Won't Live Here" by Daniel Caesar
UPDATE shares
SET preview_url = (
    SELECT preview_url
    FROM shares
    WHERE track_name ILIKE '%won%t%live%here%'
    AND artist_name ILIKE '%daniel%caesar%'
    AND is_daily_song = false
    AND preview_url IS NOT NULL
    AND preview_url != ''
    LIMIT 1
)
WHERE track_name = 'Won''t Live Here'
AND artist_name = 'Daniel Caesar'
AND is_daily_song = true
AND selected_date = CURRENT_DATE
AND (preview_url IS NULL OR preview_url = '');

-- If still no preview URL, try a more flexible match
UPDATE shares AS daily
SET preview_url = (
    SELECT preview_url
    FROM shares AS source
    WHERE source.is_daily_song = false
    AND source.preview_url IS NOT NULL
    AND source.preview_url != ''
    AND (
        -- Try various matching strategies
        source.track_id = daily.track_id OR
        (source.track_name = daily.track_name AND source.artist_name = daily.artist_name) OR
        (LOWER(source.track_name) = LOWER(daily.track_name) AND LOWER(source.artist_name) = LOWER(daily.artist_name))
    )
    ORDER BY source.created_at DESC
    LIMIT 1
)
WHERE daily.is_daily_song = true
AND daily.selected_date = CURRENT_DATE
AND (daily.preview_url IS NULL OR daily.preview_url = '');

-- Final verification - show the results
SELECT
    track_name,
    artist_name,
    preview_url,
    CASE
        WHEN preview_url IS NULL THEN '❌ No preview (NULL)'
        WHEN preview_url = '' THEN '❌ No preview (EMPTY)'
        WHEN LENGTH(preview_url) > 0 THEN '✅ Has preview (' || LENGTH(preview_url) || ' chars)'
        ELSE '❓ Unknown status'
    END as status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;

-- Show what preview URLs exist for these tracks in regular shares (for debugging)
SELECT
    'Regular share' as type,
    track_name,
    artist_name,
    LEFT(preview_url, 60) || '...' as preview_url_start,
    created_at
FROM shares
WHERE track_name IN (
    SELECT track_name
    FROM shares
    WHERE is_daily_song = true
    AND selected_date = CURRENT_DATE
)
AND is_daily_song = false
AND preview_url IS NOT NULL
AND preview_url != ''
ORDER BY track_name, created_at DESC
LIMIT 20;