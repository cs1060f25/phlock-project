-- Allow scheduled_swaps to have NULL new_member_id for pure removals (not swaps)
ALTER TABLE scheduled_swaps
  ALTER COLUMN new_member_id DROP NOT NULL;

-- Update process_scheduled_swaps to handle pure removals (new_member_id IS NULL)
CREATE OR REPLACE FUNCTION process_scheduled_swaps()
RETURNS INTEGER AS $$
DECLARE
  swap_record RECORD;
  processed_count INTEGER := 0;
  friendship_id UUID;
  old_position INTEGER;
BEGIN
  -- Loop through all pending swaps/removals that are due (scheduled_for <= NOW())
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

      -- 3. If this is a SWAP (new_member_id is not null), add new member at same position
      IF swap_record.new_member_id IS NOT NULL THEN
        -- Find friendship for new member
        SELECT id INTO friendship_id
        FROM friendships
        WHERE ((user_id_1 = swap_record.user_id AND user_id_2 = swap_record.new_member_id)
           OR (user_id_1 = swap_record.new_member_id AND user_id_2 = swap_record.user_id));

        IF friendship_id IS NULL THEN
           -- Not friends with new member
           UPDATE scheduled_swaps
           SET status = 'failed', error_message = 'Not friends with new member', updated_at = NOW()
           WHERE id = swap_record.id;
           CONTINUE;
        END IF;

        UPDATE friendships
        SET is_phlock_member = true, position = old_position, last_swapped_at = NOW()
        WHERE id = friendship_id;
      END IF;
      -- If new_member_id IS NULL, this is a pure removal - we're done after step 2

      -- 4. Mark swap/removal as completed
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
