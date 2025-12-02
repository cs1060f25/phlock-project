-- Fix demo user artwork URLs
-- Emily's "Good Days" by SZA has wrong artwork hash
-- Daniel's "Sure Thing" by Miguel may have formatting issue

-- Fix Emily's "Good Days" artwork (correct single artwork - young SZA photo)
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d0000b27304257b29be46a894e651a1a3'
WHERE track_id = '7vgTNTaEz3CsBZ1N4YQalM';

-- Verify Daniel's "Sure Thing" artwork is correctly formatted
UPDATE shares
SET album_art_url = 'https://i.scdn.co/image/ab67616d0000b273d5a8395b0d80b8c48a5d851c'
WHERE track_id = '0JXXNGljqupsJaZsgSbMZV';
