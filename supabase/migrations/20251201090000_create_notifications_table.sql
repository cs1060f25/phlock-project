-- Notifications table for client-side alerts (friend acceptances, daily nudges)
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('friend_request_accepted', 'daily_nudge')),
  message TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at
  ON public.notifications(user_id, created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can read their own notifications
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can view their notifications'
    ) THEN
        CREATE POLICY "Users can view their notifications"
          ON public.notifications
          FOR SELECT
          USING (user_id = auth.uid());
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can insert notifications they trigger or receive'
    ) THEN
        CREATE POLICY "Users can insert notifications they trigger or receive"
          ON public.notifications
          FOR INSERT
          WITH CHECK (
            actor_user_id = auth.uid()
            OR user_id = auth.uid()
          );
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update their notifications'
    ) THEN
        CREATE POLICY "Users can update their notifications"
          ON public.notifications
          FOR UPDATE
          USING (user_id = auth.uid())
          WITH CHECK (user_id = auth.uid());
    END IF;
END $$;
