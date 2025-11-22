-- Add indexes to optimize the get_user_phlocks_grouped query
-- These indexes will dramatically speed up phlock loading
-- Run this in Supabase SQL Editor or via: supabase db execute -f add_shares_indexes.sql

-- Index on sender_id for fast filtering of shares by sender
CREATE INDEX IF NOT EXISTS idx_shares_sender_id ON shares(sender_id);

-- Composite index on sender_id and track_id for the GROUP BY operation
CREATE INDEX IF NOT EXISTS idx_shares_sender_track ON shares(sender_id, track_id);

-- Index on created_at for the ORDER BY in the query
CREATE INDEX IF NOT EXISTS idx_shares_created_at ON shares(created_at DESC);

-- Index on status for the filter operations (where s.status in ('played', 'saved'))
CREATE INDEX IF NOT EXISTS idx_shares_status ON shares(status);

-- Composite index combining common query patterns
CREATE INDEX IF NOT EXISTS idx_shares_sender_created ON shares(sender_id, created_at DESC);

-- Verify indexes were created
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'shares'
ORDER BY indexname;
