-- Add phlock-related columns to friendships table if they don't exist
ALTER TABLE friendships
ADD COLUMN IF NOT EXISTS position INT CHECK (position >= 1 AND position <= 5),
ADD COLUMN IF NOT EXISTS is_phlock_member BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_swapped_at TIMESTAMPTZ;

-- Add index for phlock queries
CREATE INDEX IF NOT EXISTS idx_friendships_phlock ON friendships(user_id_1, is_phlock_member) WHERE is_phlock_member = true;
CREATE INDEX IF NOT EXISTS idx_friendships_phlock_2 ON friendships(user_id_2, is_phlock_member) WHERE is_phlock_member = true;

-- Add daily song fields to shares table if they don't exist
ALTER TABLE shares
ADD COLUMN IF NOT EXISTS is_daily_song BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS selected_date DATE,
ADD COLUMN IF NOT EXISTS preview_url TEXT;

-- Add indexes for daily song queries
CREATE INDEX IF NOT EXISTS idx_shares_daily ON shares(sender_id, is_daily_song, selected_date) WHERE is_daily_song = true;
CREATE INDEX IF NOT EXISTS idx_shares_selected_date ON shares(selected_date) WHERE is_daily_song = true;

-- Add daily curation fields to users table if they don't exist
ALTER TABLE users
ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS phlock_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS daily_song_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_daily_song_date DATE;