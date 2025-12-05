-- Add phone_hash column to users table for better contact matching
-- This allows matching contacts by hashed phone number even if the raw phone format differs

-- Add the phone_hash column
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_hash TEXT;

-- Create index for fast lookups by phone_hash
CREATE INDEX IF NOT EXISTS idx_users_phone_hash ON users(phone_hash) WHERE phone_hash IS NOT NULL;

-- Function to compute SHA256 hash of a normalized phone number
-- Normalized means: only +, 0-9 characters kept
CREATE OR REPLACE FUNCTION normalize_and_hash_phone(raw_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    normalized TEXT;
BEGIN
    -- Remove all characters except + and digits
    normalized := regexp_replace(raw_phone, '[^+0-9]', '', 'g');

    -- Return NULL if empty
    IF normalized = '' OR normalized IS NULL THEN
        RETURN NULL;
    END IF;

    -- Return SHA256 hash as hex string
    RETURN encode(digest(normalized, 'sha256'), 'hex');
END;
$$;

-- Backfill phone_hash for existing users who have a phone number
UPDATE users
SET phone_hash = normalize_and_hash_phone(phone)
WHERE phone IS NOT NULL AND phone != '' AND phone_hash IS NULL;

-- Trigger to automatically update phone_hash when phone is updated
CREATE OR REPLACE FUNCTION update_phone_hash()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.phone IS DISTINCT FROM OLD.phone THEN
        NEW.phone_hash := normalize_and_hash_phone(NEW.phone);
    END IF;
    RETURN NEW;
END;
$$;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_update_phone_hash ON users;
CREATE TRIGGER trigger_update_phone_hash
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_phone_hash();

-- RPC function to check which phone hashes belong to existing Phlock users
-- Returns the phone hashes that have a matching user in the system
CREATE OR REPLACE FUNCTION get_phlock_user_phone_hashes(phone_hashes TEXT[])
RETURNS TABLE(phone_hash TEXT)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT u.phone_hash
    FROM users u
    WHERE u.phone_hash = ANY(phone_hashes)
    AND u.phone_hash IS NOT NULL;
$$;
