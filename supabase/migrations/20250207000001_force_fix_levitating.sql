-- Force fix Levitating track with broader matching
-- This will update ALL Levitating tracks regardless of exact artist name

UPDATE shares
SET track_id = '5nujrmhLynf4yMoMtj8AQF',
    track_name = 'Levitating (feat. DaBaby)',
    album_art_url = 'https://i.scdn.co/image/ab67616d00001e022172b607853fa89cefa2beb4'
WHERE track_name ILIKE '%Levitating%'
  AND artist_name ILIKE '%Dua Lipa%';

-- Show what was updated
SELECT
  track_id,
  track_name,
  artist_name,
  substring(album_art_url, 1, 70) as album_art_url,
  CASE
    WHEN album_art_url LIKE '%2172b607853fa89cefa2beb4%' THEN '✅ FIXED'
    ELSE '❌ NOT FIXED'
  END as status
FROM shares
WHERE track_name ILIKE '%Levitating%';
