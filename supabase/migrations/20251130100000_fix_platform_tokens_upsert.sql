-- Migration: Fix platform_tokens upsert behavior
-- Date: 2025-11-30
-- Description: Add unique constraint on (user_id, platform_type) to ensure
-- upserts properly update existing tokens instead of creating duplicates.
-- This fixes the issue where reconnecting Spotify creates duplicate tokens.

-- Step 1: Remove duplicate tokens (keep the most recently updated one)
DELETE FROM platform_tokens pt1
WHERE EXISTS (
    SELECT 1 FROM platform_tokens pt2
    WHERE pt1.user_id = pt2.user_id
    AND pt1.platform_type = pt2.platform_type
    AND pt1.updated_at < pt2.updated_at
);

-- Step 2: Add unique constraint on (user_id, platform_type)
-- This ensures each user can only have one token per platform
-- Use DO block to check if constraint already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'platform_tokens_user_platform_unique'
    ) THEN
        ALTER TABLE platform_tokens
        ADD CONSTRAINT platform_tokens_user_platform_unique
        UNIQUE (user_id, platform_type);
    END IF;
END $$;

-- Step 3: Create index to optimize token lookups
CREATE INDEX IF NOT EXISTS idx_platform_tokens_user_platform
ON platform_tokens(user_id, platform_type);

-- Note: After this migration, upserts will properly update existing tokens
-- instead of creating duplicates.
