-- Fix preview URLs for daily songs
-- These are actual working preview URLs from Spotify

-- Update Blinding Lights preview URL
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/4ffd69d93a4cd2fb63c0806b561bd26f867a9c82'
WHERE track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
AND is_daily_song = true;

-- Update Peaches preview URL
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/0e7b60d0c10e42ad573e584e03c37ec42cd09e48'
WHERE track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
AND is_daily_song = true;

-- Verify the updates
SELECT
    track_name,
    artist_name,
    preview_url,
    selected_date
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;