-- Add test messages to daily songs from Tyler, Marcus, and Emma
-- Run this to test how messages appear in the Phlock tab

DO $$
DECLARE
    emma_id UUID;
    marcus_id UUID;
    tyler_id UUID;
BEGIN
    -- Get user IDs by display name
    SELECT id INTO emma_id FROM users WHERE display_name = 'Emma Rodriguez' LIMIT 1;
    SELECT id INTO marcus_id FROM users WHERE display_name = 'Marcus Chen' LIMIT 1;
    SELECT id INTO tyler_id FROM users WHERE display_name = 'Tyler Washington' LIMIT 1;

    -- Update Emma's daily song with a message
    UPDATE shares
    SET message = 'This song has been on repeat all morning! The vibes are immaculate ✨'
    WHERE sender_id = emma_id
    AND is_daily_song = true
    AND selected_date = CURRENT_DATE;

    -- Update Marcus's daily song with a message
    UPDATE shares
    SET message = 'Perfect driving music - the beat drop at 1:30 is everything 🔥'
    WHERE sender_id = marcus_id
    AND is_daily_song = true
    AND selected_date = CURRENT_DATE;

    -- Update Tyler's daily song with a message
    UPDATE shares
    SET message = 'Found this gem while producing last night. Had to share with the phlock!'
    WHERE sender_id = tyler_id
    AND is_daily_song = true
    AND selected_date = CURRENT_DATE;

    RAISE NOTICE 'Added test messages to daily songs:';
    RAISE NOTICE '  Emma: %', emma_id;
    RAISE NOTICE '  Marcus: %', marcus_id;
    RAISE NOTICE '  Tyler: %', tyler_id;
END $$;
