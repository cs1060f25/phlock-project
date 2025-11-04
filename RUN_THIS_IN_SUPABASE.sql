-- RUN THIS IN SUPABASE SQL EDITOR
-- Go to: https://supabase.com/dashboard/project/szfxnzsapojuemltjghb/sql/new

-- ============================================
-- FIX ALL ALBUM ARTWORK ISSUES
-- ============================================

-- 1. Fix HUMBLE track ID (was showing ROCKSTAR)
UPDATE shares
SET
  track_id = '7KXjTSCq5nL1LoYtL7XAwS',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e028b52c6b9bc4e43d873869699'
WHERE track_name = 'HUMBLE.'
  AND artist_name = 'Kendrick Lamar'
  AND track_id != '7KXjTSCq5nL1LoYtL7XAwS';

-- 2. Fix Peaches track ID (was showing wrong track)
UPDATE shares
SET
  track_id = '4iJyoBOLtHqaGxP12qzhQI',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e6f407c7f3a0ec98845e4431'
WHERE track_name = 'Peaches'
  AND artist_name = 'Justin Bieber'
  AND track_id != '4iJyoBOLtHqaGxP12qzhQI';

-- 3. Fix Therefore I Am (was showing Despacito)
UPDATE shares
SET
  track_id = '20R4HfKloPKgXDqU7UKk3x',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e022a038d3bf875d23e4aeaa84e'
WHERE track_name = 'Therefore I Am'
  AND artist_name = 'Billie Eilish'
  AND track_id != '20R4HfKloPKgXDqU7UKk3x';

-- 4. Fix any remaining old wrong IDs for Peaches
UPDATE shares
SET
  track_id = '4iJyoBOLtHqaGxP12qzhQI',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e6f407c7f3a0ec98845e4431'
WHERE track_id IN ('3WMj8moIAXJhHsyLaqIIHI', '4w9soAM7IrmYDhSXLp14p6')
  AND track_name = 'Peaches';

-- 5. Remove any duplicates (keeping most recent)
WITH duplicates AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY sender_id, recipient_id, track_name, artist_name
      ORDER BY created_at DESC
    ) as rn
  FROM shares
)
DELETE FROM shares
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- 6. Show results
SELECT
  track_name,
  artist_name,
  track_id,
  COUNT(*) as count,
  MIN(album_art_url) as album_art_url
FROM shares
WHERE track_name IN ('HUMBLE.', 'Peaches', 'Therefore I Am')
GROUP BY track_name, artist_name, track_id
ORDER BY track_name;