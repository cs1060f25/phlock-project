-- Add trigger to update phlock_count when users are added/removed from phlocks
-- Date: 2025-11-28
-- Description: phlock_count tracks how many people have this user in their phlock

-- Create function to update phlock_count
CREATE OR REPLACE FUNCTION update_phlock_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- If new follow has is_in_phlock = true, increment the following user's phlock_count
        IF NEW.is_in_phlock = true THEN
            UPDATE users SET phlock_count = phlock_count + 1 WHERE id = NEW.following_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle is_in_phlock changing from false to true
        IF OLD.is_in_phlock = false AND NEW.is_in_phlock = true THEN
            UPDATE users SET phlock_count = phlock_count + 1 WHERE id = NEW.following_id;
        -- Handle is_in_phlock changing from true to false
        ELSIF OLD.is_in_phlock = true AND NEW.is_in_phlock = false THEN
            UPDATE users SET phlock_count = GREATEST(0, phlock_count - 1) WHERE id = NEW.following_id;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- If deleted follow had is_in_phlock = true, decrement the following user's phlock_count
        IF OLD.is_in_phlock = true THEN
            UPDATE users SET phlock_count = GREATEST(0, phlock_count - 1) WHERE id = OLD.following_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for phlock count updates
DROP TRIGGER IF EXISTS trigger_update_phlock_count ON follows;
CREATE TRIGGER trigger_update_phlock_count
AFTER INSERT OR UPDATE OR DELETE ON follows
FOR EACH ROW EXECUTE FUNCTION update_phlock_count();

-- Initialize phlock_count from existing data
-- phlock_count = how many people have this user in their phlock
UPDATE users u SET
    phlock_count = (
        SELECT COUNT(*)
        FROM follows f
        WHERE f.following_id = u.id AND f.is_in_phlock = true
    );

-- Add helpful comment
COMMENT ON COLUMN users.phlock_count IS 'Cached count of users who have this user in their phlock';
