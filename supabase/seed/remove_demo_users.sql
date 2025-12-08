-- Remove demo users: Alex, Brittany, Cam, Daniel, Emily
-- Run this in Supabase Dashboard > SQL Editor

DO $$
DECLARE
  alex_id uuid := 'a1111111-1111-1111-1111-111111111111';
  brittany_id uuid := 'b2222222-2222-2222-2222-222222222222';
  cam_id uuid := 'c3333333-3333-3333-3333-333333333333';
  daniel_id uuid := 'd4444444-4444-4444-4444-444444444444';
  emily_id uuid := 'e5555555-5555-5555-5555-555555555555';
  demo_ids uuid[] := ARRAY[alex_id, brittany_id, cam_id, daniel_id, emily_id];
BEGIN
  -- Delete from tables that reference users (order matters for foreign keys)

  -- 1. Delete notifications involving demo users
  DELETE FROM notifications WHERE user_id = ANY(demo_ids) OR actor_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted notifications';

  -- 2. Delete follows involving demo users
  DELETE FROM follows WHERE follower_id = ANY(demo_ids) OR following_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted follows';

  -- 3. Delete phlock history involving demo users
  DELETE FROM phlock_history WHERE user_id = ANY(demo_ids) OR phlock_member_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted phlock history';

  -- 4. Delete scheduled swaps involving demo users
  DELETE FROM scheduled_swaps WHERE user_id = ANY(demo_ids) OR new_member_id = ANY(demo_ids) OR old_member_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted scheduled swaps';

  -- 5. Delete scheduled removals involving demo users
  DELETE FROM scheduled_removals WHERE user_id = ANY(demo_ids) OR member_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted scheduled removals';

  -- 6. Delete share comments from demo users
  DELETE FROM share_comments WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted share comments';

  -- 7. Delete engagements involving demo users
  DELETE FROM engagements WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted engagements';

  -- 8. Delete phlock nodes involving demo users
  DELETE FROM phlock_nodes WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted phlock nodes';

  -- 9. Delete phlocks created by demo users
  DELETE FROM phlocks WHERE created_by = ANY(demo_ids);
  RAISE NOTICE 'Deleted phlocks';

  -- 10. Delete shares involving demo users
  DELETE FROM shares WHERE sender_id = ANY(demo_ids) OR recipient_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted shares';

  -- 11. Delete friendships involving demo users (legacy table if exists)
  DELETE FROM friendships WHERE user_id = ANY(demo_ids) OR friend_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted friendships';

  -- 12. Delete platform tokens for demo users
  DELETE FROM platform_tokens WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted platform tokens';

  -- 13. Delete device tokens for demo users
  DELETE FROM device_tokens WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted device tokens';

  -- 14. Delete user contacts for demo users
  DELETE FROM user_contacts WHERE user_id = ANY(demo_ids);
  RAISE NOTICE 'Deleted user contacts';

  -- 15. Finally, delete the users themselves
  DELETE FROM users WHERE id = ANY(demo_ids);
  RAISE NOTICE 'Deleted users: Alex, Brittany, Cam, Daniel, Emily';

  RAISE NOTICE 'Demo user cleanup complete!';
END $$;

-- Verify deletion
SELECT 'Remaining demo users (should be empty):' as status;
SELECT id, username, display_name FROM users
WHERE username IN ('alex', 'brittany', 'cam', 'daniel', 'emily');
