-- Add played_at and saved_at timestamp columns to shares table
-- These columns track when a recipient played or saved a shared track

ALTER TABLE shares
ADD COLUMN IF NOT EXISTS played_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS saved_at TIMESTAMPTZ;

-- Update existing shares to set played_at for shares with status 'played' or 'saved'
-- Use created_at as a fallback timestamp
UPDATE shares
SET played_at = created_at
WHERE status IN ('played', 'saved')
  AND played_at IS NULL;

-- Update existing shares to set saved_at for shares with status 'saved'
-- Use created_at as a fallback timestamp
UPDATE shares
SET saved_at = created_at
WHERE status = 'saved'
  AND saved_at IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN shares.played_at IS 'Timestamp when the recipient first played this shared track';
COMMENT ON COLUMN shares.saved_at IS 'Timestamp when the recipient saved this shared track to their library';
