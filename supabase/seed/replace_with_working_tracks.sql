-- Alternative: Replace problematic tracks with ones that have working preview URLs
-- Run this in Supabase SQL Editor if the preview URL fix doesn't work

-- Replace Blinding Lights with Anti-Hero by Taylor Swift (has working preview)
UPDATE shares
SET
    track_id = 'spotify:track:0V3wPSX9ygBnCm8psDIegu',
    track_name = 'Anti-Hero',
    artist_name = 'Taylor Swift',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b273e0b60c608586d88252b8fbc0',
    preview_url = 'https://p.scdn.co/mp3-preview/643238728a2f91f0602793ec5d9b43e6c8eba999'
WHERE track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Replace Peaches with As It Was by Harry Styles (has working preview)
UPDATE shares
SET
    track_id = 'spotify:track:4Dvkj6JhhA12EX05fT7y2e',
    track_name = 'As It Was',
    artist_name = 'Harry Styles',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b273b46f74097655d7f353caab14',
    preview_url = 'https://p.scdn.co/mp3-preview/aad998d0cd5a2e29e7cea37d9649de4cc0cd638b'
WHERE track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
AND is_daily_song = true
AND selected_date = CURRENT_DATE;

-- Verify the replacements
SELECT
    track_name,
    artist_name,
    preview_url,
    selected_date
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;