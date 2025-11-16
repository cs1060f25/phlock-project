-- Migration: Add performance indexes for shares table
-- This dramatically improves the performance of get_user_phlocks_grouped query
-- Created: 2025-11-15

-- Index on sender_id for fast filtering of shares by sender
-- Used by: WHERE s.sender_id = p_user_id
CREATE INDEX IF NOT EXISTS idx_shares_sender_id ON public.shares(sender_id);

-- Composite index on sender_id and track_id for the GROUP BY operation
-- Used by: WHERE s.sender_id = ? GROUP BY s.track_id
CREATE INDEX IF NOT EXISTS idx_shares_sender_track ON public.shares(sender_id, track_id);

-- Index on created_at for the ORDER BY in the query
-- Used by: ORDER BY last_sent_at desc (where last_sent_at = max(created_at))
CREATE INDEX IF NOT EXISTS idx_shares_created_at ON public.shares(created_at DESC);

-- Index on status for the filter operations
-- Used by: WHERE s.status in ('played', 'saved')
CREATE INDEX IF NOT EXISTS idx_shares_status ON public.shares(status);

-- Composite index combining sender and created_at for optimal query performance
-- Covers both the WHERE and ORDER BY clauses together
CREATE INDEX IF NOT EXISTS idx_shares_sender_created ON public.shares(sender_id, created_at DESC);

-- Add a comment to document the purpose
COMMENT ON INDEX idx_shares_sender_id IS 'Optimizes filtering shares by sender';
COMMENT ON INDEX idx_shares_sender_track IS 'Optimizes grouping shares by sender and track';
COMMENT ON INDEX idx_shares_created_at IS 'Optimizes ordering shares by creation date';
COMMENT ON INDEX idx_shares_status IS 'Optimizes filtering shares by status';
COMMENT ON INDEX idx_shares_sender_created IS 'Composite index for sender queries with date ordering';
