-- Fix HUMBLE track ID and ensure proper ordering

-- 1. Fix HUMBLE track ID (was pointing to ROCKSTAR by DaBaby)
UPDATE shares
SET
  track_id = '7KXjTSCq5nL1LoYtL7XAwS',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e028b52c6b9bc4e43d873869699'
WHERE track_id = '7ytR5pFWmSjzHJIeQkgog4'
  AND track_name = 'HUMBLE.'
  AND artist_name = 'Kendrick Lamar';

-- 2. Remove any duplicate Peaches entries (keeping only the correct one)
-- First, identify duplicates
WITH peaches_duplicates AS (
  SELECT
    id,
    track_id,
    track_name,
    artist_name,
    album_art_url,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY sender_id, recipient_id, track_name, artist_name
      ORDER BY
        CASE
          WHEN track_id = '4iJyoBOLtHqaGxP12qzhQI' THEN 0  -- Correct Justin Bieber ID
          ELSE 1
        END,
        created_at DESC
    ) as rn
  FROM shares
  WHERE track_name = 'Peaches' AND artist_name = 'Justin Bieber'
)
DELETE FROM shares
WHERE id IN (
  SELECT id
  FROM peaches_duplicates
  WHERE rn > 1
);

-- 3. Fix any Peaches entries with wrong track IDs
UPDATE shares
SET
  track_id = '4iJyoBOLtHqaGxP12qzhQI',
  album_art_url = 'https://i.scdn.co/image/ab67616d00001e02e6f407c7f3a0ec98845e4431'
WHERE track_name = 'Peaches'
  AND artist_name = 'Justin Bieber'
  AND track_id != '4iJyoBOLtHqaGxP12qzhQI';

-- 4. Add milliseconds to created_at to ensure unique ordering
-- This prevents shares from having identical timestamps
UPDATE shares s1
SET created_at = s1.created_at + (
  (ROW_NUMBER() OVER (
    PARTITION BY DATE_TRUNC('minute', s1.created_at)
    ORDER BY s1.id
  ) - 1) * INTERVAL '1 millisecond'
)
FROM (
  SELECT id, created_at
  FROM shares
  WHERE created_at IN (
    SELECT created_at
    FROM shares
    GROUP BY created_at
    HAVING COUNT(*) > 1
  )
) s2
WHERE s1.id = s2.id;

-- 5. Verify the fixes
SELECT
  'Fixed tracks summary' as status,
  COUNT(CASE WHEN track_name = 'HUMBLE.' THEN 1 END) as humble_count,
  COUNT(CASE WHEN track_name = 'Peaches' THEN 1 END) as peaches_count,
  COUNT(DISTINCT created_at) as unique_timestamps,
  COUNT(*) as total_shares
FROM shares
WHERE track_name IN ('HUMBLE.', 'Peaches');