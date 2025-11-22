-- Set preview URLs to NULL for tracks that need Apple Music fallback
-- Since Spotify preview URLs are returning 404, we'll use NULL to trigger Apple Music

-- Set Blinding Lights and Peaches to NULL for Apple Music fallback
UPDATE shares
SET preview_url = NULL
WHERE track_name IN ('Blinding Lights', 'Peaches')
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Verify the changes
SELECT
    track_name,
    artist_name,
    track_id,
    CASE
        WHEN preview_url IS NULL THEN 'Will use Apple Music fallback'
        WHEN preview_url = '' THEN 'Empty - needs fix'
        ELSE 'Has Spotify preview'
    END as preview_status
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;