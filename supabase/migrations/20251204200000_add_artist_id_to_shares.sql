-- Migration: Add artist_id column to shares table
-- This enables direct linking to artist profiles on Spotify/Apple Music
-- instead of falling back to search results

-- Add artist_id column (nullable since existing shares don't have it)
ALTER TABLE shares ADD COLUMN IF NOT EXISTS artist_id TEXT;

-- Add index for potential future queries by artist
CREATE INDEX IF NOT EXISTS idx_shares_artist_id ON shares(artist_id);

-- Comment for documentation
COMMENT ON COLUMN shares.artist_id IS 'Spotify/Apple Music artist ID for direct profile linking. Format: spotify:{id} or apple:{id}';
