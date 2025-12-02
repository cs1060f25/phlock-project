-- Migration: Create platform_tokens table
-- Date: 2025-11-30
-- Description: Creates the platform_tokens table that was missing from the schema.
-- This table stores OAuth tokens for Spotify and Apple Music connections.
-- The table was being referenced but never created, causing silent storage failures.

-- Create platform_tokens table (if it doesn't exist)
-- Note: The unique constraint is added conditionally below to avoid errors if table exists
CREATE TABLE IF NOT EXISTS platform_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform_type TEXT NOT NULL CHECK (platform_type IN ('spotify', 'apple_music')),
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ NOT NULL,
    scope TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add unique constraint if it doesn't exist (ensures one token per user per platform)
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

-- Enable Row Level Security
ALTER TABLE platform_tokens ENABLE ROW LEVEL SECURITY;

-- Index for efficient lookups by user_id and platform_type
CREATE INDEX IF NOT EXISTS idx_platform_tokens_user_platform
ON platform_tokens(user_id, platform_type);

-- Drop existing policies if they exist (from 20251029020000 migration that referenced non-existent table)
DROP POLICY IF EXISTS "Users can view own tokens via auth" ON platform_tokens;
DROP POLICY IF EXISTS "Users can insert own tokens via auth" ON platform_tokens;
DROP POLICY IF EXISTS "Users can update own tokens via auth" ON platform_tokens;

-- RLS Policies using auth_user_id lookup
-- Users can only access their own tokens

CREATE POLICY "Users can view own tokens via auth"
ON platform_tokens FOR SELECT TO authenticated
USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can insert own tokens via auth"
ON platform_tokens FOR INSERT TO authenticated
WITH CHECK (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can update own tokens via auth"
ON platform_tokens FOR UPDATE TO authenticated
USING (user_id IN (SELECT id FROM users WHERE auth_user_id = auth.uid()));

-- Auto-update trigger for updated_at column
CREATE OR REPLACE FUNCTION update_platform_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_platform_tokens_updated_at ON platform_tokens;
CREATE TRIGGER update_platform_tokens_updated_at
    BEFORE UPDATE ON platform_tokens
    FOR EACH ROW EXECUTE FUNCTION update_platform_tokens_updated_at();

-- Note: The old migration 20251130100000_fix_platform_tokens_upsert.sql tried to
-- add constraints to this table before it existed. That migration can be removed
-- after this one is applied.
