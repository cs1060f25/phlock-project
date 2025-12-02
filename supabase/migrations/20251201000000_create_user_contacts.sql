-- Create user_contacts table for storing hashed phone numbers from user contacts
-- This enables the "X friends on phlock" feature like BeReal

CREATE TABLE IF NOT EXISTS user_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone_hash TEXT NOT NULL,  -- SHA256 hash of normalized phone number
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, phone_hash)
);

-- Index for fast lookups by phone_hash (used to count how many users have a contact)
CREATE INDEX IF NOT EXISTS idx_user_contacts_phone_hash ON user_contacts(phone_hash);

-- Index for fast lookups by user_id (used when syncing/deleting user's contacts)
CREATE INDEX IF NOT EXISTS idx_user_contacts_user_id ON user_contacts(user_id);

-- Enable RLS
ALTER TABLE user_contacts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own contacts
CREATE POLICY "Users can insert their own contacts"
ON user_contacts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own contacts
CREATE POLICY "Users can delete their own contacts"
ON user_contacts FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Policy: Users can read aggregate counts (but not see who uploaded what)
-- We use a function for this instead of direct table access
CREATE POLICY "Users can read their own contacts"
ON user_contacts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- RPC function to get friend counts for multiple phone hashes
-- Returns the count of distinct users who have each phone hash in their contacts
CREATE OR REPLACE FUNCTION get_friend_counts(phone_hashes TEXT[])
RETURNS TABLE(phone_hash TEXT, friend_count BIGINT)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT
        uc.phone_hash,
        COUNT(DISTINCT uc.user_id) as friend_count
    FROM user_contacts uc
    WHERE uc.phone_hash = ANY(phone_hashes)
    GROUP BY uc.phone_hash;
$$;

-- RPC function to sync user contacts (upsert)
-- Takes an array of phone hashes and inserts them for the current user
CREATE OR REPLACE FUNCTION sync_user_contacts(p_phone_hashes TEXT[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert new contacts, ignore duplicates
    INSERT INTO user_contacts (user_id, phone_hash)
    SELECT auth.uid(), unnest(p_phone_hashes)
    ON CONFLICT (user_id, phone_hash) DO NOTHING;
END;
$$;
