-- Remove song_played and song_saved notification types
-- These anonymous engagement notifications are being deprecated

-- First, delete any existing notifications of these types
DELETE FROM public.notifications
WHERE type IN ('song_played', 'song_saved');

-- Update the CHECK constraint to remove these types
ALTER TABLE public.notifications
DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
ADD CONSTRAINT notifications_type_check CHECK (type IN (
  'daily_nudge',
  'new_follower',
  'follow_request_received',
  'follow_request_accepted',
  'friend_joined',
  'phlock_song_ready',
  'streak_milestone',
  'share_liked',
  'share_commented',
  'comment_liked'
));
