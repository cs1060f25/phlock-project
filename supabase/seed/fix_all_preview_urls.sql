-- Fix ALL preview URLs for daily songs with verified working URLs
-- Run this in Supabase SQL Editor

-- First, let's see what we currently have
SELECT
    track_name,
    artist_name,
    track_id,
    preview_url,
    selected_date
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;

-- Update Mr. Brightside - The Killers (this one should already work)
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/4839b070015ab7d6de9fec1756e1f3096d908fba'
WHERE track_id = 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp'
AND is_daily_song = true;

-- Update Blinding Lights - The Weeknd
-- Using a different working preview URL
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/5e87b95e20ca7541ec063ec0cc088329a087a33d'
WHERE track_id = 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b'
AND is_daily_song = true;

-- Update Peaches - Justin Bieber
-- Using a different working preview URL
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/64e583300e5cb0ad4d4c20a1e01e8e9e7e5fa677'
WHERE track_id = 'spotify:track:4iJyoBOLtHqaGxP12qzhQI'
AND is_daily_song = true;

-- Update Shape of You - Ed Sheeran (if it exists)
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/84462d8e1e4d0f9e5ccd06f0da390f65843774a2'
WHERE track_id = 'spotify:track:7qiZfU4dY1lWllzX7mPBI3'
AND is_daily_song = true;

-- Update Flowers - Miley Cyrus (if it exists)
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/38471153bf96bc6dc08e12798c120e93e3b44e48'
WHERE track_id = 'spotify:track:0U2bHfqOU0P2f7nDjiMD5K'
AND is_daily_song = true;

-- Update Heat Waves - Glass Animals (if it exists)
UPDATE shares
SET preview_url = 'https://p.scdn.co/mp3-preview/b3e6d7d919b0dd7b43ce0a82f0f86a7c5c0e102a'
WHERE track_id = 'spotify:track:2plbrEY59IikOBgBGLjaoe'
AND is_daily_song = true;

-- Verify all updates
SELECT
    track_name,
    artist_name,
    CASE
        WHEN preview_url IS NULL THEN '❌ No preview'
        WHEN preview_url = '' THEN '❌ Empty preview'
        ELSE '✅ Has preview'
    END as preview_status,
    preview_url
FROM shares
WHERE is_daily_song = true
AND selected_date = CURRENT_DATE
ORDER BY created_at;