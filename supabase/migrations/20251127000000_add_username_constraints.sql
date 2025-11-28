-- Add username format validation and case-insensitive uniqueness
-- Date: 2025-11-27
-- Description: Ensures usernames follow format rules and are unique (case-insensitive)

-- Add check constraint for username format (3-20 chars, lowercase letters, numbers, underscores)
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_username_format;
ALTER TABLE users ADD CONSTRAINT users_username_format
  CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,20}$');

-- Create case-insensitive unique index (since username should already be unique, this adds case-insensitivity)
DROP INDEX IF EXISTS idx_users_username_lower;
CREATE UNIQUE INDEX idx_users_username_lower ON users (LOWER(username)) WHERE username IS NOT NULL;

-- Add a regular index for username lookups (for search)
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username) WHERE username IS NOT NULL;

-- Add RLS policy for username availability checks (allow anon to check if username is available)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'users' AND policyname = 'Allow username availability checks'
    ) THEN
        CREATE POLICY "Allow username availability checks"
        ON public.users FOR SELECT TO anon
        USING (true);
    END IF;
END $$;

COMMENT ON COLUMN users.username IS 'Unique username/handle for the user. Format: 3-20 lowercase alphanumeric chars and underscores.';
