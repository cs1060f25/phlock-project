-- Fix phlock_history backfill and reach_count
-- Date: 2025-12-28
-- Issue: reach_count showing as 0 even though users have been added to phlocks

-- Step 1: Ensure phlock_history table exists (in case migration wasn't fully applied)
CREATE TABLE IF NOT EXISTS phlock_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phlock_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phlock_member_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    first_added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(phlock_owner_id, phlock_member_id)
);

-- Step 2: Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_phlock_history_member ON phlock_history(phlock_member_id);
CREATE INDEX IF NOT EXISTS idx_phlock_history_owner ON phlock_history(phlock_owner_id);

-- Step 3: Ensure RLS is enabled
ALTER TABLE phlock_history ENABLE ROW LEVEL SECURITY;

-- Step 4: Ensure RLS policy exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'phlock_history' AND policyname = 'Anyone can view phlock history'
    ) THEN
        CREATE POLICY "Anyone can view phlock history"
            ON phlock_history FOR SELECT
            TO authenticated
            USING (true);
    END IF;
END $$;

-- Step 5: Ensure reach_count column exists on users
ALTER TABLE users ADD COLUMN IF NOT EXISTS reach_count INT DEFAULT 0;

-- Step 6: Re-populate phlock_history from ALL current phlock memberships
-- This catches any records that weren't migrated properly
INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
SELECT
    follower_id as phlock_owner_id,
    following_id as phlock_member_id,
    COALESCE(phlock_added_at, created_at, NOW()) as first_added_at
FROM follows
WHERE is_in_phlock = true
ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;

-- Step 7: Recalculate reach_count for ALL users
UPDATE users u SET
    reach_count = (
        SELECT COUNT(DISTINCT phlock_owner_id)
        FROM phlock_history ph
        WHERE ph.phlock_member_id = u.id
    );

-- Step 8: Ensure the trigger function exists to record future phlock additions
CREATE OR REPLACE FUNCTION record_phlock_history()
RETURNS TRIGGER AS $$
BEGIN
    -- Only record when is_in_phlock changes to true
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_in_phlock = true THEN
            INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
            VALUES (NEW.follower_id, NEW.following_id, NOW())
            ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.is_in_phlock = false AND NEW.is_in_phlock = true THEN
            INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
            VALUES (NEW.follower_id, NEW.following_id, NOW())
            ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_record_phlock_history ON follows;
CREATE TRIGGER trigger_record_phlock_history
AFTER INSERT OR UPDATE ON follows
FOR EACH ROW EXECUTE FUNCTION record_phlock_history();

-- Step 10: Ensure the reach_count update trigger function exists
CREATE OR REPLACE FUNCTION update_reach_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users SET reach_count = (
        SELECT COUNT(DISTINCT phlock_owner_id)
        FROM phlock_history
        WHERE phlock_member_id = NEW.phlock_member_id
    )
    WHERE id = NEW.phlock_member_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 11: Ensure reach_count trigger exists
DROP TRIGGER IF EXISTS trigger_update_reach_count ON phlock_history;
CREATE TRIGGER trigger_update_reach_count
AFTER INSERT ON phlock_history
FOR EACH ROW EXECUTE FUNCTION update_reach_count();

-- Log results for verification
DO $$
DECLARE
    history_count INT;
    users_with_reach INT;
BEGIN
    SELECT COUNT(*) INTO history_count FROM phlock_history;
    SELECT COUNT(*) INTO users_with_reach FROM users WHERE reach_count > 0;
    RAISE NOTICE 'Phlock history records: %, Users with reach > 0: %', history_count, users_with_reach;
END $$;
