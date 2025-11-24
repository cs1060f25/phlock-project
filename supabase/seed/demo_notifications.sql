-- Seed demo notifications for local/testing use
-- This file is safe to run multiple times; it deletes only the rows it inserts.
DO $$
DECLARE
    ids UUID[];
    target_user UUID;
    actor_one UUID;
    actor_two UUID;
    actor_three UUID;
BEGIN
    -- Grab up to four most recent users who are also auth users (best chance of matching your session)
    SELECT array_agg(u.id ORDER BY au.last_sign_in_at DESC NULLS LAST, au.created_at DESC)
    INTO ids
    FROM users u
    JOIN auth.users au ON au.id = u.id
    LIMIT 4;

    -- Fallback: if none found via auth join, just take the latest four users
    IF ids IS NULL OR array_length(ids, 1) IS NULL THEN
        SELECT array_agg(id ORDER BY created_at DESC) INTO ids FROM users LIMIT 4;
    END IF;

    -- Require at least one user to target
    IF ids IS NULL OR array_length(ids, 1) < 1 THEN
        RAISE NOTICE 'No users found to seed notifications. Skipping.';
        RETURN;
    END IF;

    target_user := ids[1];
    actor_one := COALESCE(ids[2], target_user);
    actor_two := COALESCE(ids[3], actor_one);
    actor_three := COALESCE(ids[4], actor_two);

    -- Clean up any prior demo notifications for these users (idempotent)
    DELETE FROM notifications
    WHERE user_id = target_user
      AND type IN ('friend_request_accepted', 'daily_nudge')
      AND message LIKE '%(demo)%';

    -- Build a diverse batch of notifications (friend accepts and nudges), ~20 rows
    INSERT INTO notifications (user_id, actor_user_id, type, message, metadata) VALUES
        -- Friend accepts (single actor variants)
        (target_user, actor_one,   'friend_request_accepted', 'accepted your friend request (demo 1)', NULL),
        (target_user, actor_two,   'friend_request_accepted', 'accepted your friend request (demo 2)', NULL),
        (target_user, actor_three, 'friend_request_accepted', 'accepted your friend request (demo 3)', NULL),
        (target_user, actor_one,   'friend_request_accepted', 'accepted your friend request (demo 4)', NULL),
        (target_user, actor_two,   'friend_request_accepted', 'accepted your friend request (demo 5)', NULL),
        (target_user, actor_three, 'friend_request_accepted', 'accepted your friend request (demo 6)', NULL),
        (target_user, actor_one,   'friend_request_accepted', 'accepted your friend request (demo 7)', NULL),
        (target_user, actor_two,   'friend_request_accepted', 'accepted your friend request (demo 8)', NULL),

        -- Daily nudges (single, double, triple actor variants)
        (target_user, actor_one, 'daily_nudge', 'nudged you to pick today''s song (demo A)', jsonb_build_object('actor_ids', ARRAY[actor_one::text])),
        (target_user, actor_two, 'daily_nudge', 'nudged you to pick today''s song (demo B)', jsonb_build_object('actor_ids', ARRAY[actor_two::text])),
        (target_user, actor_three, 'daily_nudge', 'nudged you to pick today''s song (demo C)', jsonb_build_object('actor_ids', ARRAY[actor_three::text])),

        (target_user, actor_one, 'daily_nudge', 'nudged you to pick today''s song (demo D)', jsonb_build_object('actor_ids', ARRAY[actor_one::text, actor_two::text])),
        (target_user, actor_two, 'daily_nudge', 'nudged you to pick today''s song (demo E)', jsonb_build_object('actor_ids', ARRAY[actor_two::text, actor_three::text])),
        (target_user, actor_three, 'daily_nudge', 'nudged you to pick today''s song (demo F)', jsonb_build_object('actor_ids', ARRAY[actor_three::text, actor_one::text])),

        (target_user, actor_one, 'daily_nudge', 'nudged you to pick today''s song (demo G)', jsonb_build_object('actor_ids', ARRAY[actor_one::text, actor_two::text, actor_three::text])),
        (target_user, actor_two, 'daily_nudge', 'nudged you to pick today''s song (demo H)', jsonb_build_object('actor_ids', ARRAY[actor_two::text, actor_three::text, actor_one::text])),
        (target_user, actor_three, 'daily_nudge', 'nudged you to pick today''s song (demo I)', jsonb_build_object('actor_ids', ARRAY[actor_three::text, actor_one::text, actor_two::text])),

        -- Extra singles to pad to ~20 rows and cover recent timestamps
        (target_user, actor_one,   'friend_request_accepted', 'accepted your friend request (demo 9)', NULL),
        (target_user, actor_two,   'friend_request_accepted', 'accepted your friend request (demo 10)', NULL),
        (target_user, actor_three, 'friend_request_accepted', 'accepted your friend request (demo 11)', NULL);

    RAISE NOTICE 'Seeded demo notifications for user % with actors %, %, %', target_user, actor_one, actor_two, actor_three;
END $$;
