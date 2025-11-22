-- Dummy data for testing daily playlist feature
-- This script adds phlock members and their daily songs for testing

-- First, ensure our test user has the right auth_user_id
DO $$
DECLARE
    test_user_id UUID;
    friend1_id UUID;
    friend2_id UUID;
    friend3_id UUID;
    friend4_id UUID;
    friend5_id UUID;
    today DATE := CURRENT_DATE;
BEGIN
    -- Get or update our test user
    SELECT id INTO test_user_id FROM users
    WHERE auth_user_id = '45db2427-9b99-49bf-a334-895ec91b038c'::uuid;

    IF test_user_id IS NULL THEN
        -- Update an existing user to be our test user
        SELECT id INTO test_user_id FROM users LIMIT 1;
        UPDATE users SET auth_user_id = '45db2427-9b99-49bf-a334-895ec91b038c'::uuid
        WHERE id = test_user_id;
    END IF;

    -- Update test user's daily song fields
    UPDATE users
    SET daily_song_streak = 3,
        last_daily_song_date = today,
        username = 'testuser'
    WHERE id = test_user_id;

    -- Get 5 friends to be phlock members
    SELECT id INTO friend1_id FROM users WHERE display_name = 'Emma' LIMIT 1;
    SELECT id INTO friend2_id FROM users WHERE display_name = 'Marcus' LIMIT 1;
    SELECT id INTO friend3_id FROM users WHERE display_name = 'Sofia' LIMIT 1;
    SELECT id INTO friend4_id FROM users WHERE display_name = 'Tyler' LIMIT 1;
    SELECT id INTO friend5_id FROM users WHERE display_name = 'Maya' LIMIT 1;

    -- Update friendships to make them phlock members with positions
    -- Position 1: Emma
    UPDATE friendships
    SET is_phlock_member = true,
        position = 1,
        last_swapped_at = NOW()
    WHERE ((user_id_1 = test_user_id AND user_id_2 = friend1_id)
        OR (user_id_1 = friend1_id AND user_id_2 = test_user_id))
    AND status = 'accepted';

    -- Position 2: Marcus
    UPDATE friendships
    SET is_phlock_member = true,
        position = 2,
        last_swapped_at = NOW()
    WHERE ((user_id_1 = test_user_id AND user_id_2 = friend2_id)
        OR (user_id_1 = friend2_id AND user_id_2 = test_user_id))
    AND status = 'accepted';

    -- Position 3: Sofia
    UPDATE friendships
    SET is_phlock_member = true,
        position = 3,
        last_swapped_at = NOW()
    WHERE ((user_id_1 = test_user_id AND user_id_2 = friend3_id)
        OR (user_id_1 = friend3_id AND user_id_2 = test_user_id))
    AND status = 'accepted';

    -- Position 4: Tyler
    UPDATE friendships
    SET is_phlock_member = true,
        position = 4,
        last_swapped_at = NOW()
    WHERE ((user_id_1 = test_user_id AND user_id_2 = friend4_id)
        OR (user_id_1 = friend4_id AND user_id_2 = test_user_id))
    AND status = 'accepted';

    -- Position 5: Maya (optional - you can leave this empty to test add functionality)
    UPDATE friendships
    SET is_phlock_member = true,
        position = 5,
        last_swapped_at = NOW()
    WHERE ((user_id_1 = test_user_id AND user_id_2 = friend5_id)
        OR (user_id_1 = friend5_id AND user_id_2 = test_user_id))
    AND status = 'accepted';

    -- Clean up any existing daily songs for today
    DELETE FROM shares
    WHERE is_daily_song = true
    AND selected_date = today
    AND sender_id IN (friend1_id, friend2_id, friend3_id, friend4_id, friend5_id);

    -- Add daily songs for each phlock member
    -- Emma's daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        friend1_id,
        friend1_id, -- Self-reference for daily songs
        'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp', -- Mr. Brightside
        'Mr. Brightside',
        'The Killers',
        'https://i.scdn.co/image/ab67616d0000b273ccdddd46119a4ff53eaf1f5d',
        'https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba',
        'Classic vibes today!',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    -- Marcus's daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        friend2_id,
        friend2_id,
        'spotify:track:0VjIjW4GlUZAMYd2vXMi3b', -- Blinding Lights
        'Blinding Lights',
        'The Weeknd',
        'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5aeb36',
        'https://p.scdn.co/mp3-preview/e9f1e0e7e3c6c1277f29c1df52c5af5b6e26a55c',
        'Can''t stop listening to this',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    -- Sofia's daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        friend3_id,
        friend3_id,
        'spotify:track:4iJyoBOLtHqaGxP12qzhQI', -- Peaches
        'Peaches (feat. Daniel Caesar & Giveon)',
        'Justin Bieber',
        'https://i.scdn.co/image/ab67616d0000b273e6f407c7f3a0ec98845e4431',
        'https://p.scdn.co/mp3-preview/8cc84b3df71da3f32f1b66ca83cd985e14f9c759',
        'Summer vibes 🍑',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    -- Tyler's daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        friend4_id,
        friend4_id,
        'spotify:track:7qiZfU4dY1lWllzX7mPBI3', -- Shape of You
        'Shape of You',
        'Ed Sheeran',
        'https://i.scdn.co/image/ab67616d0000b273ba5db46f4b838ef6027e6f96',
        'https://p.scdn.co/mp3-preview/84462d8e1e4d0f9e5ccd06f0da390f65843774a2',
        'Always a banger',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    -- Maya's daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        friend5_id,
        friend5_id,
        'spotify:track:0U2bHfqOU0P2f7nDjiMD5K', -- Flowers
        'Flowers',
        'Miley Cyrus',
        'https://i.scdn.co/image/ab67616d0000b273f429549123dbe8552764ba1d',
        'https://p.scdn.co/mp3-preview/9e6b779a56e09fb17c3c4e784a87fdd97d6c0f15',
        'Self love anthem 💐',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    -- Add test user's own daily song
    INSERT INTO shares (
        id, sender_id, recipient_id, track_id, track_name, artist_name,
        album_art_url, preview_url, message, status, is_daily_song, selected_date,
        created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        test_user_id,
        test_user_id,
        'spotify:track:2plbrEY59IikOBgBGLjaoe', -- Heat Waves
        'Heat Waves',
        'Glass Animals',
        'https://i.scdn.co/image/ab67616d0000b273712b9c0f9a8d380e26a95e1f',
        'https://p.scdn.co/mp3-preview/b3e6d7d919b0dd7b43ce0a82f0f86a7c5c0e102a',
        'My mood today',
        'sent',
        true,
        today,
        NOW(),
        NOW()
    );

    RAISE NOTICE 'Daily playlist dummy data created successfully!';
    RAISE NOTICE 'Test user ID: %', test_user_id;
    RAISE NOTICE 'Phlock members: Emma (%), Marcus (%), Sofia (%), Tyler (%), Maya (%)',
                 friend1_id, friend2_id, friend3_id, friend4_id, friend5_id;
END $$;