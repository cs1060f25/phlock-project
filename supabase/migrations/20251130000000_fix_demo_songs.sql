-- Fix demo user daily songs with verified Spotify metadata
-- This replaces the incorrect artwork URLs with verified ones from Spotify API

-- Alex: Bad (2012 Remaster) - Michael Jackson
UPDATE shares
SET track_id = '2gSNBigeWMVtY3QBIvPAEc',
    track_name = 'Bad - 2012 Remaster',
    artist_name = 'Michael Jackson',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b2732e0cd1330748a5b7764dd562',
    preview_url = NULL
WHERE sender_id = 'a1111111-1111-1111-1111-111111111111'
  AND is_daily_song = true;

-- Brittany: Lost - Frank Ocean
UPDATE shares
SET track_id = '3GZD6HmiNUhxXYf8Gch723',
    track_name = 'Lost',
    artist_name = 'Frank Ocean',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b2737aede4855f6d0d738012e2e5',
    preview_url = NULL
WHERE sender_id = 'b2222222-2222-2222-2222-222222222222'
  AND is_daily_song = true;

-- Cam: White Teeth - Ryan Beatty
UPDATE shares
SET track_id = '3Gqagi4hGvcHyoWznBi4q3',
    track_name = 'White Teeth',
    artist_name = 'Ryan Beatty',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b27389bcf0e9d8e14d33dea77acf',
    preview_url = NULL
WHERE sender_id = 'c3333333-3333-3333-3333-333333333333'
  AND is_daily_song = true;

-- Daniel: Real Life - The Weeknd
UPDATE shares
SET track_id = '03j354P848KtNU2FVSwkDG',
    track_name = 'Real Life',
    artist_name = 'The Weeknd',
    album_art_url = 'https://i.scdn.co/image/ab67616d0000b2737fcead687e99583072cc217b',
    preview_url = NULL
WHERE sender_id = 'd4444444-4444-4444-4444-444444444444'
  AND is_daily_song = true;
