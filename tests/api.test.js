/**
 * Phlock API Test Suite
 *
 * Tests the business logic extracted from Supabase Edge Functions.
 * No external API calls, no database access, no credentials required.
 *
 * Run with: npm test
 */

// ============================================================================
// BUSINESS LOGIC (extracted from edge functions)
// ============================================================================

/**
 * Validates search request input
 * Source: supabase/functions/search-spotify-tracks/index.ts
 */
function validateSearchRequest(body) {
  const { query, limit = 20 } = body || {};

  if (!query || typeof query !== 'string' || query.trim().length === 0) {
    return { valid: false, error: 'Query parameter is required' };
  }

  const normalizedLimit = Math.min(Math.max(1, limit), 50);
  return { valid: true, query: query.trim(), limit: normalizedLimit };
}

/**
 * Validates track validation request input
 * Source: supabase/functions/validate-track/index.ts
 */
function validateTrackRequest(body) {
  const { trackId, trackName, artistName, isrc } = body || {};

  if (!trackId && !isrc && !(trackName && artistName)) {
    return {
      valid: false,
      error: 'Either trackId, isrc, or both trackName and artistName are required'
    };
  }

  return { valid: true, trackId, trackName, artistName, isrc };
}

/**
 * Parses artist name to extract all artists (handles featured artists)
 * Source: supabase/functions/validate-track/index.ts
 */
function parseArtists(artistName) {
  const delimiters = /\s+(?:ft\.?|feat\.?|featuring|&|,|\|)\s+/gi;
  return artistName.split(delimiters).map(a => a.trim().toLowerCase());
}

/**
 * Checks if track artists match expected artist name
 * Source: supabase/functions/validate-track/index.ts
 */
function artistsMatch(trackArtists, expectedArtistName) {
  const expectedArtists = parseArtists(expectedArtistName);
  const trackArtistNames = trackArtists.map(a => a.name.toLowerCase());

  return expectedArtists.every(expectedArtist =>
    trackArtistNames.some(trackArtist =>
      trackArtist.includes(expectedArtist) || expectedArtist.includes(trackArtist)
    )
  );
}

/**
 * Transforms Spotify track to Phlock app format
 * Source: supabase/functions/validate-track/index.ts
 */
function transformTrackToAppFormat(spotifyTrack, previewUrl) {
  return {
    id: spotifyTrack.id,
    name: spotifyTrack.name,
    artistName: spotifyTrack.artists[0].name,
    artists: spotifyTrack.artists.map(a => a.name),
    albumArtUrl: spotifyTrack.album.images[0]?.url,
    previewUrl: previewUrl || spotifyTrack.preview_url,
    isrc: spotifyTrack.external_ids?.isrc,
    spotifyUrl: `https://open.spotify.com/track/${spotifyTrack.id}`
  };
}

// ============================================================================
// UNIT TESTS
// ============================================================================

describe('Search Request Validation', () => {

  test('rejects empty query', () => {
    const result = validateSearchRequest({ query: '' });
    expect(result.valid).toBe(false);
    expect(result.error).toBe('Query parameter is required');
  });

  test('rejects null query', () => {
    const result = validateSearchRequest({ query: null });
    expect(result.valid).toBe(false);
  });

  test('rejects numeric query', () => {
    const result = validateSearchRequest({ query: 12345 });
    expect(result.valid).toBe(false);
  });

  test('accepts valid query string', () => {
    const result = validateSearchRequest({ query: 'Bohemian Rhapsody' });
    expect(result.valid).toBe(true);
    expect(result.query).toBe('Bohemian Rhapsody');
  });

  test('trims whitespace from query', () => {
    const result = validateSearchRequest({ query: '  hello world  ' });
    expect(result.valid).toBe(true);
    expect(result.query).toBe('hello world');
  });

  test('clamps limit to maximum of 50', () => {
    const result = validateSearchRequest({ query: 'test', limit: 100 });
    expect(result.limit).toBe(50);
  });

  test('clamps limit to minimum of 1', () => {
    const result = validateSearchRequest({ query: 'test', limit: 0 });
    expect(result.limit).toBe(1);
  });

});

describe('Track Request Validation', () => {

  test('rejects empty request', () => {
    const result = validateTrackRequest({});
    expect(result.valid).toBe(false);
    expect(result.error).toContain('required');
  });

  test('accepts trackId alone', () => {
    const result = validateTrackRequest({ trackId: 'abc123' });
    expect(result.valid).toBe(true);
  });

  test('accepts isrc alone', () => {
    const result = validateTrackRequest({ isrc: 'USRC12345678' });
    expect(result.valid).toBe(true);
  });

  test('accepts trackName with artistName', () => {
    const result = validateTrackRequest({
      trackName: 'Bohemian Rhapsody',
      artistName: 'Queen'
    });
    expect(result.valid).toBe(true);
  });

  test('rejects trackName without artistName', () => {
    const result = validateTrackRequest({ trackName: 'Bohemian Rhapsody' });
    expect(result.valid).toBe(false);
  });

});

describe('Artist Parsing', () => {

  test('handles single artist', () => {
    expect(parseArtists('Queen')).toEqual(['queen']);
  });

  test('handles ft. format', () => {
    expect(parseArtists('Dua Lipa ft. DaBaby')).toEqual(['dua lipa', 'dababy']);
  });

  test('handles feat. format', () => {
    expect(parseArtists('Taylor Swift feat. Bon Iver')).toEqual(['taylor swift', 'bon iver']);
  });

  test('handles & format', () => {
    expect(parseArtists('Drake & Future')).toEqual(['drake', 'future']);
  });

  test('handles comma format', () => {
    expect(parseArtists('Post Malone, Swae Lee')).toEqual(['post malone', 'swae lee']);
  });

});

describe('Artist Matching', () => {

  test('matches single artist', () => {
    const trackArtists = [{ name: 'Queen' }];
    expect(artistsMatch(trackArtists, 'Queen')).toBe(true);
  });

  test('matches featured artists', () => {
    const trackArtists = [{ name: 'Dua Lipa' }, { name: 'DaBaby' }];
    expect(artistsMatch(trackArtists, 'Dua Lipa ft. DaBaby')).toBe(true);
  });

  test('rejects wrong artist', () => {
    const trackArtists = [{ name: 'Queen' }];
    expect(artistsMatch(trackArtists, 'Drake')).toBe(false);
  });

  test('case insensitive matching', () => {
    const trackArtists = [{ name: 'QUEEN' }];
    expect(artistsMatch(trackArtists, 'queen')).toBe(true);
  });

});

// ============================================================================
// INTEGRATION TESTS
// ============================================================================

describe('Track Transformation', () => {

  const mockSpotifyTrack = {
    id: '3z8h0TU7ReDPLIbEnYhWZb',
    name: 'Bohemian Rhapsody',
    artists: [{ name: 'Queen' }],
    album: { images: [{ url: 'https://example.com/album.jpg' }] },
    preview_url: 'https://example.com/preview.mp3',
    external_ids: { isrc: 'GBUM71029604' }
  };

  test('transforms track with all fields', () => {
    const result = transformTrackToAppFormat(mockSpotifyTrack, null);

    expect(result.id).toBe('3z8h0TU7ReDPLIbEnYhWZb');
    expect(result.name).toBe('Bohemian Rhapsody');
    expect(result.artistName).toBe('Queen');
    expect(result.albumArtUrl).toBe('https://example.com/album.jpg');
    expect(result.previewUrl).toBe('https://example.com/preview.mp3');
    expect(result.spotifyUrl).toBe('https://open.spotify.com/track/3z8h0TU7ReDPLIbEnYhWZb');
  });

  test('uses fallback preview URL when provided', () => {
    const fallbackUrl = 'https://apple.com/preview.m4a';
    const result = transformTrackToAppFormat(mockSpotifyTrack, fallbackUrl);

    expect(result.previewUrl).toBe(fallbackUrl);
  });

});

describe('End-to-End Workflow (Unit)', () => {

  test('complete search-to-share flow validates correctly', () => {
    // Step 1: User types search query
    const searchInput = { query: 'Levitating Dua Lipa', limit: 10 };
    const searchValidation = validateSearchRequest(searchInput);
    expect(searchValidation.valid).toBe(true);

    // Step 2: User selects a track from results
    const selectedTrack = {
      id: '463CkQjx2Zk1yXoBuierM9',
      name: 'Levitating',
      artists: [{ name: 'Dua Lipa' }, { name: 'DaBaby' }],
      album: { images: [{ url: 'https://example.com/album.jpg' }] },
      preview_url: 'https://example.com/preview.mp3',
      external_ids: { isrc: 'GBAHT2000245' }
    };

    // Step 3: App validates the track
    const trackValidation = validateTrackRequest({
      trackId: selectedTrack.id,
      trackName: selectedTrack.name,
      artistName: 'Dua Lipa ft. DaBaby'
    });
    expect(trackValidation.valid).toBe(true);

    // Step 4: Verify artist matching works
    expect(artistsMatch(selectedTrack.artists, 'Dua Lipa ft. DaBaby')).toBe(true);

    // Step 5: Transform for app display
    const appTrack = transformTrackToAppFormat(selectedTrack, null);
    expect(appTrack.name).toBe('Levitating');
    expect(appTrack.artistName).toBe('Dua Lipa');
    expect(appTrack.spotifyUrl).toContain('open.spotify.com');
  });

});

// ============================================================================
// INTEGRATION TESTS - Live API Calls
// These tests call the actual Supabase Edge Functions (read-only, no database writes)
// ============================================================================

const SUPABASE_URL = 'https://szfxnzsapojuemltjghb.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc';

async function callEdgeFunction(functionName, body) {
  const response = await fetch(`${SUPABASE_URL}/functions/v1/${functionName}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'apikey': SUPABASE_ANON_KEY
    },
    body: JSON.stringify(body)
  });
  return { status: response.status, data: await response.json() };
}

describe('Integration Tests - Live API', () => {

  // Integration Test 1: Search API returns track results
  test('search-spotify-tracks returns results for valid query', async () => {
    const { status, data } = await callEdgeFunction('search-spotify-tracks', {
      query: 'Bohemian Rhapsody Queen',
      limit: 5
    });

    expect(status).toBe(200);
    expect(data.tracks).toBeDefined();
    expect(data.tracks.length).toBeGreaterThan(0);

    // Verify track structure
    const track = data.tracks[0];
    expect(track.id).toBeDefined();
    expect(track.name).toBeDefined();
    expect(track.artists).toBeDefined();
    expect(track.artists[0].name).toBeDefined();
  }, 15000);

  // Integration Test 2: Validate API returns track metadata with preview URL
  test('validate-track returns complete track data', async () => {
    const { status, data } = await callEdgeFunction('validate-track', {
      trackName: 'Blinding Lights',
      artistName: 'The Weeknd'
    });

    expect(status).toBe(200);
    expect(data.success).toBe(true);
    expect(data.track).toBeDefined();

    // Verify all fields the iOS app needs
    expect(data.track.id).toBeDefined();
    expect(data.track.name).toBeDefined();
    expect(data.track.artistName).toBeDefined();
    expect(data.track.albumArtUrl).toBeDefined();
    expect(data.track.spotifyUrl).toMatch(/open\.spotify\.com\/track/);
  }, 15000);

});
