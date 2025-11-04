-- Fix bad track IDs in existing shares
-- This corrects the track IDs that were pointing to wrong songs

-- Therefore I Am by Billie Eilish
-- Old (incorrect): 6habFhsOp2NvshLv26DqMb (actually "Despacito" by Luis Fonsi)
-- New (correct): 20R4HfKloPKgXDqU7UKk3x
UPDATE shares
SET
  track_id = '20R4HfKloPKgXDqU7UKk3x',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e022a038d3bf875d23e4aeaa84e'
WHERE track_id = '6habFhsOp2NvshLv26DqMb'
  AND track_name = 'Therefore I Am'
  AND artist_name = 'Billie Eilish';

-- Peaches by Justin Bieber
-- Old (incorrect): 3WMj8moIAXJhHsyLaqIIHI (actually "Something in the Orange" by Zach Bryan)
-- New (correct): 4iJyoBOLtHqaGxP12qzhQI
UPDATE shares
SET
  track_id = '4iJyoBOLtHqaGxP12qzhQI',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e6f407c7f3a0ec98845e4431'
WHERE track_id = '3WMj8moIAXJhHsyLaqIIHI'
  AND track_name = 'Peaches'
  AND artist_name = 'Justin Bieber';

-- Also update any shares that might have been created with the wrong Jack Black version
UPDATE shares
SET
  track_id = '4iJyoBOLtHqaGxP12qzhQI',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e6f407c7f3a0ec98845e4431'
WHERE track_id = '4w9soAM7IrmYDhSXLp14p6'
  AND track_name = 'Peaches'
  AND artist_name = 'Justin Bieber';

SELECT
  'Fixed track IDs for existing shares' as status,
  COUNT(*) as updated_rows
FROM shares
WHERE track_id IN ('20R4HfKloPKgXDqU7UKk3x', '4iJyoBOLtHqaGxP12qzhQI');
