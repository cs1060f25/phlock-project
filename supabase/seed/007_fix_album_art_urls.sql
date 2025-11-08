-- Fix album art URLs and track IDs for seed data
-- This fixes issues with stale or invalid Spotify URLs

-- Watermelon Sugar by Harry Styles
UPDATE shares
SET track_id = '6UelLqGlWMcVH1E5c4H7lY',
    album_art_url = 'https://i.scdn.co/image/ab67616d00001e0277fdcfda6535601aff081b6a'
WHERE track_name = 'Watermelon Sugar' AND artist_name = 'Harry Styles';

-- Peaches by Justin Bieber (keeping the correct search result for Justin Bieber's song)
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e02ef0d4234e1a645740f77d59c'
WHERE track_name = 'Peaches' AND artist_name = 'Justin Bieber';

-- Therefore I Am by Billie Eilish
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e022a038d3bf875d23e4aeaa84e'
WHERE track_name = 'Therefore I Am' AND artist_name = 'Billie Eilish';

-- Mr. Brightside by The Killers
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e02ccdddd46119a4ff53eaf1f5d'
WHERE track_name = 'Mr. Brightside' AND artist_name = 'The Killers';

-- Blinding Lights by The Weeknd
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e028863bc11d2aa12b54f5aeb36'
WHERE track_name = 'Blinding Lights' AND artist_name = 'The Weeknd';

-- Shape of You by Ed Sheeran
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e02ba5db46f4b838ef6027e6f96'
WHERE track_name = 'Shape of You' AND artist_name = 'Ed Sheeran';

-- Someone Like You by Adele
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e022118bf9b198b05a95ded6300'
WHERE track_name = 'Someone Like You' AND artist_name = 'Adele';

-- One Dance by Drake
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e029416ed64daf84936d89e671c'
WHERE track_name = 'One Dance' AND artist_name LIKE 'Drake%';

-- Levitating by Dua Lipa (feat. DaBaby version)
UPDATE shares
SET track_id = '5nujrmhLynf4yMoMtj8AQF',
    track_name = 'Levitating (feat. DaBaby)',
    album_art_url = 'https://i.scdn.co/image/ab67616d00001e022172b607853fa89cefa2beb4'
WHERE track_name LIKE 'Levitating%' AND artist_name = 'Dua Lipa';

-- Sunflower by Post Malone
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e2e352d89826aef6dbd5ff8f'
WHERE track_name = 'Sunflower' AND artist_name = 'Post Malone';

-- HUMBLE. by Kendrick Lamar
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e028b52c6b9bc4e43d873869699'
WHERE track_name = 'HUMBLE.' AND artist_name = 'Kendrick Lamar';

-- God's Plan by Drake
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e02f907de96b9a4fbc04accc0d5'
WHERE track_name = 'God''s Plan' AND artist_name = 'Drake';

-- Starboy by The Weeknd
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d00001e024718e2b124f79258be7bc452'
WHERE track_name = 'Starboy' AND artist_name LIKE 'The Weeknd%';

-- Time by Pink Floyd (keeping original as the search result was incorrect)
-- No update needed

SELECT 'Album art URLs updated successfully!' as status;
