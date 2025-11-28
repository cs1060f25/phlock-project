-- Update notification types to support full notification system
-- Date: 2025-11-28
-- Description: Expands the notification type constraint to include all required notification types

-- First, clean up any notifications with old types that won't be supported
DELETE FROM notifications WHERE type NOT IN (
  'daily_nudge',
  'new_follower',
  'follow_request_received',
  'follow_request_accepted',
  'friend_joined',
  'phlock_song_ready',
  'song_played',
  'song_saved',
  'streak_milestone'
);

-- Drop existing constraint and add new one with all types
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
CHECK (type IN (
  'daily_nudge',
  'new_follower',
  'follow_request_received',
  'follow_request_accepted',
  'friend_joined',
  'phlock_song_ready',
  'song_played',
  'song_saved',
  'streak_milestone'
));

-- Add index for efficient querying of notifications by user and type
CREATE INDEX IF NOT EXISTS idx_notifications_user_type
ON notifications(user_id, type, created_at DESC);

-- Update accept_follow_request function to create notification
CREATE OR REPLACE FUNCTION accept_follow_request(request_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_requester_id UUID;
    v_target_id UUID;
    v_status TEXT;
BEGIN
    -- Get the request details
    SELECT requester_id, target_id, status INTO v_requester_id, v_target_id, v_status
    FROM follow_requests
    WHERE id = request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Follow request not found';
    END IF;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'Follow request already processed';
    END IF;

    -- Update the request status
    UPDATE follow_requests
    SET status = 'accepted', responded_at = NOW()
    WHERE id = request_id;

    -- Create the follow relationship
    INSERT INTO follows (follower_id, following_id)
    VALUES (v_requester_id, v_target_id)
    ON CONFLICT (follower_id, following_id) DO NOTHING;

    -- Create notification for the requester that their request was accepted
    INSERT INTO notifications (user_id, actor_user_id, type, message)
    VALUES (v_requester_id, v_target_id, 'follow_request_accepted', NULL);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment explaining the notification types
COMMENT ON COLUMN notifications.type IS 'Notification types:
- daily_nudge: Phlock members nudge you to pick a song (aggregated)
- new_follower: Someone followed you
- follow_request_received: Private profile received follow request
- follow_request_accepted: Your follow request was approved
- friend_joined: A contact joined the app
- phlock_song_ready: A phlock member picked their daily song
- song_played: Someone played your daily song (aggregated, anonymous)
- song_saved: Someone saved your daily song (aggregated, anonymous)
- streak_milestone: Reached a daily song streak milestone';
