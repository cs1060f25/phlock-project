-- Migration: Add platform OAuth support
-- Date: 2025-10-24
-- Description: Update users table and create platform_tokens table for Spotify/Apple Music authentication

-- Add platform authentication fields to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS platform_type TEXT,
ADD COLUMN IF NOT EXISTS platform_user_id TEXT,
ADD COLUMN IF NOT EXISTS platform_data JSONB;

-- Remove phone requirement (no longer using phone auth)
ALTER TABLE users
ALTER COLUMN phone DROP NOT NULL;

-- Create unique constraint on platform auth
CREATE UNIQUE INDEX IF NOT EXISTS users_platform_unique
ON users(platform_type, platform_user_id);

-- Create platform tokens table
CREATE TABLE IF NOT EXISTS platform_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform_type TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    scope TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS platform_tokens_user_id_idx ON platform_tokens(user_id);
CREATE INDEX IF NOT EXISTS platform_tokens_platform_type_idx ON platform_tokens(platform_type);

-- Enable RLS
ALTER TABLE platform_tokens ENABLE ROW LEVEL SECURITY;

-- RLS policies: users can only access their own tokens
CREATE POLICY "Users can view own tokens"
ON platform_tokens FOR SELECT
USING (auth.uid()::uuid = user_id);

CREATE POLICY "Users can insert own tokens"
ON platform_tokens FOR INSERT
WITH CHECK (auth.uid()::uuid = user_id);

CREATE POLICY "Users can update own tokens"
ON platform_tokens FOR UPDATE
USING (auth.uid()::uuid = user_id);
