-- Create device_tokens table for push notifications
-- Date: 2025-11-27
-- Description: Stores APNs device tokens for iOS push notifications

CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    is_sandbox BOOLEAN DEFAULT FALSE, -- true for development/TestFlight, false for production
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- A user can have multiple devices, but each token should be unique per platform
    UNIQUE(device_token, platform)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(device_token);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- RLS policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'device_tokens' AND policyname = 'Users can view own device tokens'
    ) THEN
        CREATE POLICY "Users can view own device tokens"
        ON device_tokens FOR SELECT TO authenticated
        USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'device_tokens' AND policyname = 'Users can insert own device tokens'
    ) THEN
        CREATE POLICY "Users can insert own device tokens"
        ON device_tokens FOR INSERT TO authenticated
        WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'device_tokens' AND policyname = 'Users can update own device tokens'
    ) THEN
        CREATE POLICY "Users can update own device tokens"
        ON device_tokens FOR UPDATE TO authenticated
        USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'device_tokens' AND policyname = 'Users can delete own device tokens'
    ) THEN
        CREATE POLICY "Users can delete own device tokens"
        ON device_tokens FOR DELETE TO authenticated
        USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));
    END IF;
END $$;

-- Function to upsert device token (register or update)
CREATE OR REPLACE FUNCTION register_device_token(
    p_user_id UUID,
    p_device_token TEXT,
    p_platform TEXT DEFAULT 'ios',
    p_is_sandbox BOOLEAN DEFAULT FALSE
)
RETURNS UUID AS $$
DECLARE
    v_token_id UUID;
BEGIN
    INSERT INTO device_tokens (user_id, device_token, platform, is_sandbox, updated_at)
    VALUES (p_user_id, p_device_token, p_platform, p_is_sandbox, NOW())
    ON CONFLICT (device_token, platform)
    DO UPDATE SET
        user_id = EXCLUDED.user_id,
        is_sandbox = EXCLUDED.is_sandbox,
        updated_at = NOW()
    RETURNING id INTO v_token_id;

    RETURN v_token_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION register_device_token(UUID, TEXT, TEXT, BOOLEAN) TO authenticated;

COMMENT ON TABLE device_tokens IS 'Stores device tokens for push notifications (APNs for iOS)';
COMMENT ON COLUMN device_tokens.is_sandbox IS 'True for development/TestFlight builds, false for App Store production';
