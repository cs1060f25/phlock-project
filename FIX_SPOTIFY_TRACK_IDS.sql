-- Fix incorrect Spotify track IDs in shares and phlocks tables

-- 1. Shape of You by Ed Sheeran
-- Wrong: 7qiZfU4dY1lWllzX7mPBI
-- Correct: 7qiZfU4dY1lWllzX7mPBI3 (missing the '3' at the end)
UPDATE shares
SET track_id = '7qiZfU4dY1lWllzX7mPBI3'
WHERE track_name = 'Shape of You'
  AND artist_name = 'Ed Sheeran'
  AND track_id = '7qiZfU4dY1lWllzX7mPBI';

UPDATE phlocks
SET track_id = '7qiZfU4dY1lWllzX7mPBI3'
WHERE track_name = 'Shape of You'
  AND artist_name = 'Ed Sheeran'
  AND track_id = '7qiZfU4dY1lWllzX7mPBI';

-- 2. Someone Like You by Adele
-- Wrong: 3qiyyUfYe7CRYLucrPmulD
-- Correct: 1zwMYTA5nlNjZxYrvBB2pV
UPDATE shares
SET track_id = '1zwMYTA5nlNjZxYrvBB2pV'
WHERE track_name = 'Someone Like You'
  AND artist_name = 'Adele'
  AND track_id = '3qiyyUfYe7CRYLucrPmulD';

UPDATE phlocks
SET track_id = '1zwMYTA5nlNjZxYrvBB2pV'
WHERE track_name = 'Someone Like You'
  AND artist_name = 'Adele'
  AND track_id = '3qiyyUfYe7CRYLucrPmulD';

-- 3. One Dance by Drake
-- Wrong: 0DiWol3AO6WpXZgp0goxAV
-- Correct: 1zi7xx7UVEFkmKfv06H8x0
UPDATE shares
SET track_id = '1zi7xx7UVEFkmKfv06H8x0'
WHERE track_name = 'One Dance'
  AND (artist_name LIKE 'Drake%' OR artist_name = 'Drake')
  AND track_id = '0DiWol3AO6WpXZgp0goxAV';

UPDATE phlocks
SET track_id = '1zi7xx7UVEFkmKfv06H8x0'
WHERE track_name = 'One Dance'
  AND (artist_name LIKE 'Drake%' OR artist_name = 'Drake')
  AND track_id = '0DiWol3AO6WpXZgp0goxAV';

-- 4. Levitating by Dua Lipa
-- Wrong: 3DamFFqW32WihKkTVlwTYQ
-- Correct: 2SAqBLGA283SUiwJ3xOUVI
UPDATE shares
SET track_id = '2SAqBLGA283SUiwJ3xOUVI'
WHERE track_name = 'Levitating'
  AND artist_name = 'Dua Lipa'
  AND track_id = '3DamFFqW32WihKkTVlwTYQ';

UPDATE phlocks
SET track_id = '2SAqBLGA283SUiwJ3xOUVI'
WHERE track_name = 'Levitating'
  AND artist_name = 'Dua Lipa'
  AND track_id = '3DamFFqW32WihKkTVlwTYQ';

-- 5. Sunflower by Post Malone
-- Wrong: 4cOdK2wGLETKBW3PvgPWqT
-- Correct: 0RiRZpuVRbi7oqRdSMwhQY
UPDATE shares
SET track_id = '0RiRZpuVRbi7oqRdSMwhQY'
WHERE track_name = 'Sunflower'
  AND artist_name = 'Post Malone'
  AND track_id = '4cOdK2wGLETKBW3PvgPWqT';

UPDATE phlocks
SET track_id = '0RiRZpuVRbi7oqRdSMwhQY'
WHERE track_name = 'Sunflower'
  AND artist_name = 'Post Malone'
  AND track_id = '4cOdK2wGLETKBW3PvgPWqT';

-- Summary of what was changed
DO $$
BEGIN
  RAISE NOTICE '✅ Fixed Spotify track IDs for:';
  RAISE NOTICE '   - Shape of You: Added missing "3" at the end';
  RAISE NOTICE '   - Someone Like You: Updated to correct ID';
  RAISE NOTICE '   - One Dance: Updated to correct ID';
  RAISE NOTICE '   - Levitating: Updated to correct ID';
  RAISE NOTICE '   - Sunflower: Updated to correct ID';
END $$;