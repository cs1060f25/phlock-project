-- Force Apple Music fallback for today's Blinding Lights + Peaches daily songs
-- Spotify preview URLs for these tracks keep returning 404s, so we clear them out
-- to let the client fetch a working Apple Music preview instead.

-- Target by track_id (preferred) with a name fallback for any mismatched metadata.
WITH cleared AS (
    UPDATE shares
    SET
        preview_url = NULL,
        updated_at = NOW()
    WHERE is_daily_song = true
      AND selected_date = CURRENT_DATE
      AND (
          track_id IN (
              'spotify:track:0VjIjW4GlUZAMYd2vXMi3b', -- Blinding Lights
              'spotify:track:4iJyoBOLtHqaGxP12qzhQI'  -- Peaches
          )
          OR track_name ILIKE 'Blinding Lights%'
          OR track_name ILIKE 'Peaches%'
      )
    RETURNING id, track_name, artist_name, track_id, selected_date
)
SELECT
    track_name,
    artist_name,
    track_id,
    selected_date,
    'Will use Apple Music fallback' AS preview_status
FROM cleared
ORDER BY track_name;
