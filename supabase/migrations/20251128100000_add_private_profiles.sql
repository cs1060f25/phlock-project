-- Add private profile support
-- Date: 2025-11-28
-- Description: Users can toggle their profile between public and private.
--              Private profiles require follow requests to be approved.

-- Add is_private column to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- Create follow_requests table for private profile follow requests
CREATE TABLE IF NOT EXISTS follow_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ,

    -- Prevent duplicate requests
    UNIQUE(requester_id, target_id),

    -- Prevent self-requests
    CHECK (requester_id != target_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_follow_requests_requester ON follow_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_follow_requests_target ON follow_requests(target_id);
CREATE INDEX IF NOT EXISTS idx_follow_requests_status ON follow_requests(status);
CREATE INDEX IF NOT EXISTS idx_follow_requests_target_pending ON follow_requests(target_id, status) WHERE status = 'pending';

-- Enable RLS
ALTER TABLE follow_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DO $$
BEGIN
    -- Users can view follow requests they sent or received
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follow_requests' AND policyname = 'Users can view their follow requests'
    ) THEN
        CREATE POLICY "Users can view their follow requests"
        ON follow_requests FOR SELECT
        TO authenticated
        USING (
            requester_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
            OR target_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
        );
    END IF;

    -- Users can create follow requests (as requester)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follow_requests' AND policyname = 'Users can send follow requests'
    ) THEN
        CREATE POLICY "Users can send follow requests"
        ON follow_requests FOR INSERT
        TO authenticated
        WITH CHECK (requester_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    -- Users can update follow requests they received (to accept/reject)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follow_requests' AND policyname = 'Users can respond to follow requests'
    ) THEN
        CREATE POLICY "Users can respond to follow requests"
        ON follow_requests FOR UPDATE
        TO authenticated
        USING (target_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    -- Users can delete follow requests they sent (cancel) or received (after responding)
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'follow_requests' AND policyname = 'Users can delete follow requests'
    ) THEN
        CREATE POLICY "Users can delete follow requests"
        ON follow_requests FOR DELETE
        TO authenticated
        USING (
            requester_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
            OR target_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid())
        );
    END IF;
END $$;

-- Function to handle follow request acceptance
-- When a follow request is accepted, create the follow relationship
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

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION accept_follow_request(UUID) TO authenticated;

-- Add helpful comments
COMMENT ON COLUMN users.is_private IS 'If true, users must request to follow and profile content is hidden from non-followers';
COMMENT ON TABLE follow_requests IS 'Pending follow requests for private profiles';
COMMENT ON COLUMN follow_requests.status IS 'pending = awaiting response, accepted = approved (follow created), rejected = denied';
