-- ⚠️⚠️⚠️ DUMMY DATA MIGRATION - FOR DEMO ONLY ⚠️⚠️⚠️
-- This migration creates phlock-related tables and populates them with dummy data
-- for demonstration purposes. This should be REVERTED before production use.
--
-- To revert: DROP TABLE shares, phlocks, phlock_nodes, engagements CASCADE;
--
-- Created: 2024-10-29
-- Purpose: CS1060 HW7 Demo - Phlock Visualization Feature
-- ⚠️⚠️⚠️ DUMMY DATA MIGRATION - FOR DEMO ONLY ⚠️⚠️⚠️

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ====================
-- SHARES TABLE
-- ====================
-- Tracks individual music shares between users
CREATE TABLE IF NOT EXISTS shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,
  track_id VARCHAR(255) NOT NULL, -- Spotify/Apple Music ID
  track_name VARCHAR(500) NOT NULL,
  artist_name VARCHAR(500) NOT NULL,
  album_art_url TEXT,
  message TEXT, -- Optional note from sender (max 280 chars)
  status VARCHAR(50) DEFAULT 'sent' CHECK (status IN ('sent', 'received', 'played', 'saved', 'forwarded', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_shares_sender ON shares(sender_id);
CREATE INDEX IF NOT EXISTS idx_shares_recipient ON shares(recipient_id);
CREATE INDEX IF NOT EXISTS idx_shares_track ON shares(track_id);
CREATE INDEX IF NOT EXISTS idx_shares_created_at ON shares(created_at DESC);

-- ====================
-- PHLOCKS TABLE
-- ====================
-- Metadata for each phlock (unique origin share)
CREATE TABLE IF NOT EXISTS phlocks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  origin_share_id UUID REFERENCES shares(id) ON DELETE CASCADE,
  created_by UUID REFERENCES users(id) ON DELETE CASCADE,
  track_id VARCHAR(255) NOT NULL,
  track_name VARCHAR(500) NOT NULL,
  artist_name VARCHAR(500) NOT NULL,
  album_art_url TEXT,
  total_reach INT DEFAULT 0, -- Total unique people reached
  max_depth INT DEFAULT 0, -- Maximum generations (0 = just you)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(origin_share_id) -- One phlock per origin share
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_phlocks_created_by ON phlocks(created_by);
CREATE INDEX IF NOT EXISTS idx_phlocks_track ON phlocks(track_id);
CREATE INDEX IF NOT EXISTS idx_phlocks_created_at ON phlocks(created_at DESC);

-- ====================
-- PHLOCK_NODES TABLE
-- ====================
-- Individual nodes in the phlock network visualization
CREATE TABLE IF NOT EXISTS phlock_nodes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phlock_id UUID REFERENCES phlocks(id) ON DELETE CASCADE NOT NULL,
  share_id UUID REFERENCES shares(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  depth INT NOT NULL DEFAULT 0, -- Generation: 0=creator, 1=direct friends, 2=second gen, etc.
  parent_node_id UUID REFERENCES phlock_nodes(id) ON DELETE CASCADE, -- NULL for root node
  forwarded BOOLEAN DEFAULT FALSE,
  saved BOOLEAN DEFAULT FALSE,
  played BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (depth >= 0),
  CHECK (depth = 0 OR parent_node_id IS NOT NULL) -- Non-root nodes must have parent
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_phlock_nodes_phlock ON phlock_nodes(phlock_id);
CREATE INDEX IF NOT EXISTS idx_phlock_nodes_user ON phlock_nodes(user_id);
CREATE INDEX IF NOT EXISTS idx_phlock_nodes_parent ON phlock_nodes(parent_node_id);
CREATE INDEX IF NOT EXISTS idx_phlock_nodes_depth ON phlock_nodes(depth);

-- ====================
-- ENGAGEMENTS TABLE
-- ====================
-- Tracks all user actions on received shares
CREATE TABLE IF NOT EXISTS engagements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  share_id UUID REFERENCES shares(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  action VARCHAR(50) NOT NULL CHECK (action IN ('played', 'saved', 'forwarded', 'dismissed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_engagements_share ON engagements(share_id);
CREATE INDEX IF NOT EXISTS idx_engagements_user ON engagements(user_id);
CREATE INDEX IF NOT EXISTS idx_engagements_action ON engagements(action);
CREATE INDEX IF NOT EXISTS idx_engagements_created_at ON engagements(created_at DESC);

-- ====================
-- TRIGGERS
-- ====================
-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_shares_updated_at ON shares;
CREATE TRIGGER update_shares_updated_at BEFORE UPDATE ON shares
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_phlocks_updated_at ON phlocks;
CREATE TRIGGER update_phlocks_updated_at BEFORE UPDATE ON phlocks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ====================
-- ROW LEVEL SECURITY
-- ====================
-- Enable RLS on all tables
ALTER TABLE shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE phlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE phlock_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagements ENABLE ROW LEVEL SECURITY;

-- Policies: Users can view phlocks they created or are part of
-- Drop existing policies first (in case of re-run)
DROP POLICY IF EXISTS "Users can view their own shares" ON shares;
DROP POLICY IF EXISTS "Users can view their own phlocks" ON phlocks;
DROP POLICY IF EXISTS "Users can view nodes in their phlocks" ON phlock_nodes;
DROP POLICY IF EXISTS "Users can view engagements on their shares" ON engagements;

CREATE POLICY "Users can view their own shares"
  ON shares FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can view their own phlocks"
  ON phlocks FOR SELECT
  USING (auth.uid() = created_by);

CREATE POLICY "Users can view nodes in their phlocks"
  ON phlock_nodes FOR SELECT
  USING (
    phlock_id IN (SELECT id FROM phlocks WHERE created_by = auth.uid())
    OR user_id = auth.uid()
  );

CREATE POLICY "Users can view engagements on their shares"
  ON engagements FOR SELECT
  USING (
    share_id IN (SELECT id FROM shares WHERE sender_id = auth.uid() OR recipient_id = auth.uid())
  );

-- ⚠️⚠️⚠️ MIGRATION COMPLETE ⚠️⚠️⚠️
-- Remember: This creates tables for dummy data demo only!
-- Run the seed file next to populate with demonstration data.
