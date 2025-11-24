-- Temporarily clear today's daily song for the primary test user so the flow can be re-run.
-- Run in the Supabase SQL editor.

DO $$
DECLARE
    target UUID;
BEGIN
    SELECT id INTO target
    FROM users
    WHERE auth_user_id = '45db2427-9b99-49bf-a334-895ec91b038c'
    LIMIT 1;

    IF target IS NULL THEN
        RAISE NOTICE 'No user found for given auth_user_id';
        RETURN;
    END IF;

    -- Delete ALL daily songs for this user (regardless of date format/value)
    DELETE FROM shares
    WHERE is_daily_song = true
      AND sender_id = target;

    RAISE NOTICE 'Cleared daily songs for user %', target;
END $$;

-- Verify it’s cleared
WITH target_user AS (
    SELECT id
    FROM users
    WHERE auth_user_id = '45db2427-9b99-49bf-a334-895ec91b038c'
    LIMIT 1
)
SELECT sender_id, track_name, selected_date
FROM shares
WHERE is_daily_song = true
  AND sender_id IN (SELECT id FROM target_user);
