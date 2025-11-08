-- Create share_comments table for tweet-sized threads on shared songs
-- This enables 1-to-1 conversation threads on each share

CREATE TABLE IF NOT EXISTS share_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  share_id UUID NOT NULL REFERENCES shares(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  comment_text TEXT NOT NULL CHECK (char_length(comment_text) <= 280),
  parent_comment_id UUID REFERENCES share_comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for efficient queries
CREATE INDEX idx_share_comments_share_id ON share_comments(share_id);
CREATE INDEX idx_share_comments_user_id ON share_comments(user_id);
CREATE INDEX idx_share_comments_created_at ON share_comments(created_at DESC);
CREATE INDEX idx_share_comments_parent_id ON share_comments(parent_comment_id) WHERE parent_comment_id IS NOT NULL;

-- Add composite index for conversation queries (sender/recipient combinations)
CREATE INDEX idx_shares_conversation ON shares(sender_id, recipient_id, created_at DESC);
CREATE INDEX idx_shares_conversation_reverse ON shares(recipient_id, sender_id, created_at DESC);

-- Add index for grouping shares by track (for Phlocks view)
CREATE INDEX idx_shares_track_grouping ON shares(sender_id, track_id, created_at DESC);

-- Enable Row Level Security
ALTER TABLE share_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for share_comments

-- Users can view comments on shares they're part of (sender or recipient)
CREATE POLICY "Users can view comments on their shares"
  ON share_comments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (shares.sender_id = auth.uid() OR shares.recipient_id = auth.uid())
    )
  );

-- Users can create comments on shares they're part of
CREATE POLICY "Users can comment on their shares"
  ON share_comments
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM shares
      WHERE shares.id = share_comments.share_id
      AND (shares.sender_id = auth.uid() OR shares.recipient_id = auth.uid())
    )
  );

-- Users can update their own comments
CREATE POLICY "Users can update own comments"
  ON share_comments
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own comments
CREATE POLICY "Users can delete own comments"
  ON share_comments
  FOR DELETE
  USING (user_id = auth.uid());

-- Add function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_share_comments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_share_comments_updated_at
  BEFORE UPDATE ON share_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_share_comments_updated_at();

-- Add comment count to shares for efficient display
ALTER TABLE shares ADD COLUMN IF NOT EXISTS comment_count INTEGER DEFAULT 0;

-- Function to update comment count
CREATE OR REPLACE FUNCTION update_share_comment_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE shares
    SET comment_count = comment_count + 1
    WHERE id = NEW.share_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE shares
    SET comment_count = GREATEST(comment_count - 1, 0)
    WHERE id = OLD.share_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_share_comment_count_trigger
  AFTER INSERT OR DELETE ON share_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_share_comment_count();
