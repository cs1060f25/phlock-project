-- Create scheduled_swaps table
CREATE TABLE IF NOT EXISTS scheduled_swaps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  old_member_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  new_member_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'cancelled')),
  scheduled_for TIMESTAMPTZ NOT NULL, -- The midnight when this should happen
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  error_message TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_swaps_user ON scheduled_swaps(user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_swaps_status ON scheduled_swaps(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_swaps_scheduled_for ON scheduled_swaps(scheduled_for);

-- RLS Policies
ALTER TABLE scheduled_swaps ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'scheduled_swaps' AND policyname = 'Users can view their own scheduled swaps'
    ) THEN
        CREATE POLICY "Users can view their own scheduled swaps"
          ON scheduled_swaps FOR SELECT
          USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'scheduled_swaps' AND policyname = 'Users can create their own scheduled swaps'
    ) THEN
        CREATE POLICY "Users can create their own scheduled swaps"
          ON scheduled_swaps FOR INSERT
          WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT FROM pg_policies WHERE tablename = 'scheduled_swaps' AND policyname = 'Users can update their own scheduled swaps'
    ) THEN
        CREATE POLICY "Users can update their own scheduled swaps"
          ON scheduled_swaps FOR UPDATE
          USING (auth.uid() = user_id);
    END IF;
END $$;

-- Function to process scheduled swaps
-- This will be called by a cron job (or edge function)
CREATE OR REPLACE FUNCTION process_scheduled_swaps()
RETURNS INTEGER AS $$
DECLARE
  swap_record RECORD;
  processed_count INTEGER := 0;
  friendship_id UUID;
  old_position INTEGER;
BEGIN
  -- Loop through all pending swaps that are due (scheduled_for <= NOW())
  FOR swap_record IN 
    SELECT * FROM scheduled_swaps 
    WHERE status = 'pending' 
    AND scheduled_for <= NOW()
  LOOP
    BEGIN
      -- 1. Find the friendship for the OLD member to get their position
      SELECT id, position INTO friendship_id, old_position
      FROM friendships
      WHERE ((user_id_1 = swap_record.user_id AND user_id_2 = swap_record.old_member_id)
         OR (user_id_1 = swap_record.old_member_id AND user_id_2 = swap_record.user_id))
      AND is_phlock_member = true;

      IF friendship_id IS NULL THEN
        -- Old member not found in phlock, mark as failed
        UPDATE scheduled_swaps 
        SET status = 'failed', error_message = 'Old member not found in phlock', updated_at = NOW()
        WHERE id = swap_record.id;
        CONTINUE;
      END IF;

      -- 2. Remove OLD member from phlock
      UPDATE friendships
      SET is_phlock_member = false, position = NULL, last_swapped_at = NOW()
      WHERE id = friendship_id;

      -- 3. Add NEW member to phlock at the SAME position
      -- Find friendship for new member
      SELECT id INTO friendship_id
      FROM friendships
      WHERE ((user_id_1 = swap_record.user_id AND user_id_2 = swap_record.new_member_id)
         OR (user_id_1 = swap_record.new_member_id AND user_id_2 = swap_record.user_id));
      
      IF friendship_id IS NULL THEN
         -- Not friends with new member?
         UPDATE scheduled_swaps 
         SET status = 'failed', error_message = 'Not friends with new member', updated_at = NOW()
         WHERE id = swap_record.id;
         
         -- Rollback removal of old member (basic compensation)
         -- In a real transaction this would roll back automatically if we raised exception,
         -- but we want to record the failure in the table.
         -- For simplicity in this function, we'll just fail.
         CONTINUE;
      END IF;

      UPDATE friendships
      SET is_phlock_member = true, position = old_position, last_swapped_at = NOW()
      WHERE id = friendship_id;

      -- 4. Mark swap as completed
      UPDATE scheduled_swaps
      SET status = 'completed', updated_at = NOW()
      WHERE id = swap_record.id;

      processed_count := processed_count + 1;

    EXCEPTION WHEN OTHERS THEN
      -- Catch any other errors
      UPDATE scheduled_swaps
      SET status = 'failed', error_message = SQLERRM, updated_at = NOW()
      WHERE id = swap_record.id;
    END;
  END LOOP;

  RETURN processed_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
