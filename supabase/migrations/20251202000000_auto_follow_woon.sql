-- Auto-follow @woon for new users
-- Every new user will automatically follow @woon and have @woon in position 1 of their phlock
-- @woon's user ID: 7d1ca118-b5b1-4a73-a6ed-850dd22575dc

CREATE OR REPLACE FUNCTION auto_follow_woon()
RETURNS TRIGGER AS $$
DECLARE
    woon_id UUID := '7d1ca118-b5b1-4a73-a6ed-850dd22575dc';
BEGIN
    -- Don't create self-follow if the new user IS woon
    IF NEW.id = woon_id THEN
        RETURN NEW;
    END IF;

    -- Insert follow record (new user follows woon, with woon in phlock position 1)
    INSERT INTO follows (follower_id, following_id, is_in_phlock, phlock_position, phlock_added_at)
    VALUES (NEW.id, woon_id, true, 1, NOW())
    ON CONFLICT (follower_id, following_id) DO NOTHING;

    -- Update woon's follower_count
    UPDATE users SET follower_count = COALESCE(follower_count, 0) + 1 WHERE id = woon_id;

    -- Update new user's following_count
    UPDATE users SET following_count = COALESCE(following_count, 0) + 1 WHERE id = NEW.id;

    -- Add to phlock_history for reach tracking
    INSERT INTO phlock_history (phlock_owner_id, phlock_member_id, first_added_at)
    VALUES (NEW.id, woon_id, NOW())
    ON CONFLICT (phlock_owner_id, phlock_member_id) DO NOTHING;

    -- Update woon's phlock_count (how many people have woon in their phlock)
    UPDATE users SET phlock_count = COALESCE(phlock_count, 0) + 1 WHERE id = woon_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on users table
DROP TRIGGER IF EXISTS auto_follow_woon_trigger ON users;
CREATE TRIGGER auto_follow_woon_trigger
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION auto_follow_woon();
