# Dynamic Track Validation System

## Overview

This system provides a dynamic, scalable solution for validating and correcting Spotify track IDs without hardcoding. It consists of three components:

1. **Node.js Script** - For bulk validation and fixing existing data
2. **Edge Function** - For real-time validation when tracks are shared
3. **iOS Integration** - Automatic validation in ShareService

## Components

### 1. Bulk Track ID Fixer (`fix_track_ids_dynamic.js`)

A Node.js script that:
- Fetches all tracks from your database
- Validates each track ID against Spotify API
- Searches for correct tracks when IDs are invalid
- Generates SQL statements to fix incorrect IDs
- Works dynamically without any hardcoding

**Usage:**
```bash
# Set your Spotify credentials (get from https://developer.spotify.com/dashboard)
export SPOTIFY_CLIENT_SECRET=your_client_secret

# Run the script
node fix_track_ids_dynamic.js

# The script will output SQL statements to fix any incorrect IDs
# Copy and run them in your database
```

**Features:**
- ✅ Validates existing track IDs
- ✅ Detects mismatched metadata
- ✅ Searches for correct tracks automatically
- ✅ Generates SQL fixes dynamically
- ✅ Shows popularity scores to help identify correct versions
- ✅ Updates album artwork URLs

### 2. Edge Function (`validate-track`)

A Supabase Edge Function that provides real-time track validation:
- Validates track IDs
- Searches for tracks by name/artist
- Returns correct metadata
- Handles mismatches automatically

**Deployment:**
```bash
# Deploy the edge function
supabase functions deploy validate-track

# Set environment variables in Supabase dashboard
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

**API Usage:**
```javascript
// Validate by track ID
const response = await fetch('https://your-project.supabase.co/functions/v1/validate-track', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    trackId: '7qiZfU4dY1lWllzX7mPBI3'
  })
});

// Search by name and artist
const response = await fetch('https://your-project.supabase.co/functions/v1/validate-track', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    trackName: 'Shape of You',
    artistName: 'Ed Sheeran'
  })
});

// Validate with expected metadata
const response = await fetch('https://your-project.supabase.co/functions/v1/validate-track', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_ANON_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    trackId: 'some_id',
    trackName: 'Expected Name',
    artistName: 'Expected Artist'
  })
});
```

### 3. iOS Integration

The ShareService now automatically validates tracks when creating shares:

```swift
// In ShareService.swift
private func validateTrackMetadata(_ track: MusicItem) async throws -> MusicItem {
    // Automatically validates and corrects track IDs
    // Uses the validate-track edge function
    // Returns track with corrected ID and fresh metadata
}

// When creating a share
func createShare(track: MusicItem, ...) async throws {
    // Track is automatically validated before saving
    let validatedTrack = try await validateTrackMetadata(track)
    // Share is created with correct track ID
}
```

## Benefits Over Hardcoding

1. **Scalability** - Works with any number of tracks
2. **Accuracy** - Always gets the latest correct IDs from Spotify
3. **Maintenance-free** - No need to update hardcoded IDs
4. **Self-healing** - Automatically fixes issues as they arise
5. **Metadata refresh** - Updates album art and other metadata

## How It Works

### Track Validation Flow:

1. **Check existing ID** - Validates if the current track ID is valid
2. **Verify metadata** - Ensures the track matches expected name/artist
3. **Search if needed** - Finds the correct track if ID is invalid or mismatched
4. **Return best match** - Prioritizes exact matches, falls back to most popular

### Matching Algorithm:

```typescript
// 1. Try exact match
const exactMatch = tracks.find(track =>
  track.name.toLowerCase() === expectedName.toLowerCase() &&
  track.artists.some(artist =>
    artist.name.toLowerCase() === expectedArtist.toLowerCase()
  )
);

// 2. Fall back to most popular
const bestMatch = tracks.sort((a, b) => b.popularity - a.popularity)[0];
```

## Setup Instructions

### 1. Deploy the Edge Function

```bash
cd supabase/functions
supabase functions deploy validate-track
```

### 2. Set Environment Variables

In Supabase Dashboard > Settings > Edge Functions:
- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`

### 3. Fix Existing Data

```bash
# Install dependencies
npm install node-fetch @supabase/supabase-js

# Run the fixer
export SPOTIFY_CLIENT_SECRET=your_secret
node fix_track_ids_dynamic.js

# Apply the generated SQL fixes
```

### 4. Test the System

```bash
# Test the edge function
curl -X POST https://your-project.supabase.co/functions/v1/validate-track \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"trackName": "Shape of You", "artistName": "Ed Sheeran"}'
```

## Common Issues and Solutions

### Issue: Track not found
**Solution:** The search uses exact matching first. Try variations:
- Remove "ft." or "feat." from artist names
- Use the primary artist only
- Check for spelling differences

### Issue: Wrong version returned
**Solution:** The system prioritizes popularity. For specific versions:
- Include version info in track name (e.g., "Song - Acoustic")
- Use ISRC codes for exact matching (future enhancement)

### Issue: Rate limiting
**Solution:** The script includes delays. For large datasets:
- Process in batches
- Increase delay between requests
- Use Spotify's batch endpoints

## Future Enhancements

1. **ISRC Matching** - Use International Standard Recording Codes for exact version matching
2. **Batch Processing** - Process multiple tracks in single API calls
3. **Caching** - Cache validated tracks to reduce API calls
4. **Cross-Platform** - Add Apple Music validation
5. **Automatic Fixes** - Auto-apply fixes without manual SQL

## Monitoring

Check validation success rates:
```sql
-- Tracks that failed validation (need manual review)
SELECT track_name, artist_name, track_id, COUNT(*)
FROM shares
WHERE track_id NOT IN (
  SELECT DISTINCT track_id
  FROM shares
  WHERE track_id ~ '^[a-zA-Z0-9]{22}$'
)
GROUP BY track_name, artist_name, track_id;

-- Most shared tracks (prioritize fixing these)
SELECT track_name, artist_name, COUNT(*) as share_count
FROM shares
GROUP BY track_name, artist_name
ORDER BY share_count DESC
LIMIT 20;
```

## API Rate Limits

Spotify API limits:
- **Client Credentials**: No user-specific rate limit
- **General**: ~180 requests per minute
- **Search**: Subject to additional limits

The system includes:
- Automatic delays between requests
- Exponential backoff on errors
- Batch processing capabilities

---

This dynamic system ensures your track IDs are always correct without maintaining hardcoded lists!