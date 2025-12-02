-- Create phlock_history table to track historical phlock memberships
-- This enables "reach" stat: count of unique users who have ever had you in their phlock
-- Date: 2025-11-28

-- Create the history table
CREATE TABLE IF NOT EXISTS phlock_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- The user who added someone to their phlock
    phlock_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- The user who was added to the phlock
    phlock_member_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- When they were first added (we only care about the first time)
    first_added_at TIMESTAMPTZ DEFAULT NOW(),

    -- Each pair should only have one record (first time they were added)
    UNIQUE(phlock_owner_id, phlock_member_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_phlock_history_member ON phlock_history(phlock_member_id);
CREATE INDEX IF NOT EXISTS idx_phlock_history_owner ON phlock_history(phlock_owner_id);

-- Enable RLS
ALTER TABLE phlock_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Anyone authenticated can read phlock history
DROP POLICY IF EXISTS "Anyone can view phlock history" ON phlock_history;
CREATE POLICY "Anyone can view phlock history"
    ON phlock_history FOR SELECT
    TO authenticated
    USING (true);

-- Only the system (via triggers) should insert into this table
-- Users don't insert directly, so we use a SECURITY DEFINER function

-- Create function to record phlock addition in history
CREATE OR REPLACE FUNCTION record_phlock_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Only record when is_in_phlock changes to true
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_in_phlock = true THEN
            -- Insert into history, ignore if already exists (ON CONFLICT DO NOTHING)
            INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
            VALUES (NEW.follower_id, NEW.following_id, NOW())
            ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_in_phlock = false AND NEW.is_in_phlock = true THEN
            -- Insert into history, ignore if already exists
            INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
            VALUES (NEW.follower_id, NEW.following_id, NOW())
            ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for recording phlock history
DROP TRIGGER IF EXISTS trigger_record_phlock_history ON follows;
CREATE TRIGGER trigger_record_phlock_history
AFTER INSERT OR UPDATE ON follows
FOR EACH ROW EXECUTE FUNCTION record_phlock_history();

-- Migrate existing phlock memberships to history table
-- This captures any current is_in_phlock = true records
INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
SELECT
    follower_id as phlock_owner_id,
    following_id as phlock_member_id,
    COALESCE(phlock_added_at, created_at, NOW()) as first_added_at
FROM follows
WHERE is_in_phlock = true
ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;

-- Add reach_count column to users table for caching (optional optimization)
ALTER TABLE users ADD COLUMN IF NOT EXISTS reach_count INT DEFAULT 0;

-- Create function to update reach_count
CREATE OR REPLACE FUNCTION update_reach_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the reach_count for the phlock_member (the person who was added)
    UPDATE users SET reach_count = (
        SELECT COUNT(DISTINCT phlock_owner_id)
        FROM phlock_history
        WHERE phlock_member_id = NEW.phlock_member_id
    )
    WHERE id = NEW.phlock_member_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update reach_count when history is added
DROP TRIGGER IF EXISTS trigger_update_reach_count ON phlock_history;
CREATE TRIGGER trigger_update_reach_count
AFTER INSERT ON phlock_history
FOR EACH ROW EXECUTE FUNCTION update_reach_count();

-- Initialize reach_count from existing history data
UPDATE users u SET
    reach_count = (
        SELECT COUNT(DISTINCT phlock_owner_id)
        FROM phlock_history ph
        WHERE ph.phlock_member_id = u.id
    );

-- Add helpful comments
COMMENT ON TABLE phlock_history IS 'Tracks historical phlock memberships for reach calculation';
COMMENT ON COLUMN phlock_history.phlock_owner_id IS 'User who owns the phlock (added someone)';
COMMENT ON COLUMN phlock_history.phlock_member_id IS 'User who was added to the phlock';
COMMENT ON COLUMN phlock_history.first_added_at IS 'When they were first added to this phlock';
COMMENT ON COLUMN users.reach_count IS 'Cached count of unique users who have ever had this user in their phlock';
