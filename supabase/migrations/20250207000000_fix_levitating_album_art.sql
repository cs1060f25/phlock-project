-- Fix Levitating track ID and album artwork
-- This updates existing shares in the database

UPDATE shares
SET track_id = '5nujrmhLynf4yMoMtj8AQF',
    track_name = 'Levitating (feat. DaBaby)',
    album_art_url = 'https://i.scdn.co/image/ab67616d00001e022172b607853fa89cefa2beb4'
WHERE track_name LIKE '%Levitating%'
  AND artist_name = 'Dua Lipa';

-- Show the updated records
SELECT track_id, track_name, artist_name, album_art_url
FROM shares
WHERE track_name LIKE '%Levitating%'
  AND artist_name = 'Dua Lipa';
