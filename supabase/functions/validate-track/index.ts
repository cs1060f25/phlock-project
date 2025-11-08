import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TrackValidationRequest {
  trackId?: string;
  trackName?: string;
  artistName?: string;
  isrc?: string;  // For exact version matching
}

interface SpotifyToken {
  access_token: string;
  token_type: string;
  expires_in: number;
}

interface SpotifyTrack {
  id: string;
  name: string;
  artists: Array<{ name: string }>;
  album: {
    images: Array<{ url: string; height: number; width: number }>;
  };
  preview_url: string | null;
  external_ids?: {
    isrc?: string;
  };
  popularity: number;
}

/**
 * Get Spotify access token using client credentials
 */
async function getSpotifyToken(): Promise<SpotifyToken> {
  const clientId = Deno.env.get('SPOTIFY_CLIENT_ID') ?? '';
  const clientSecret = Deno.env.get('SPOTIFY_CLIENT_SECRET') ?? '';

  const response = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + btoa(`${clientId}:${clientSecret}`)
    },
    body: 'grant_type=client_credentials'
  });

  if (!response.ok) {
    throw new Error('Failed to get Spotify access token');
  }

  return await response.json();
}

/**
 * Validate a track ID by fetching it from Spotify
 */
async function validateTrackId(trackId: string, accessToken: string): Promise<SpotifyTrack | null> {
  const response = await fetch(`https://api.spotify.com/v1/tracks/${trackId}`, {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  });

  if (response.status === 200) {
    return await response.json();
  }

  return null;
}

/**
 * Search for a track by ISRC (most precise matching)
 */
async function searchByISRC(isrc: string, accessToken: string): Promise<SpotifyTrack | null> {
  const query = `isrc:${isrc}`;
  const encodedQuery = encodeURIComponent(query);

  const response = await fetch(
    `https://api.spotify.com/v1/search?q=${encodedQuery}&type=track&limit=1`,
    {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    }
  );

  if (!response.ok) {
    console.error('Spotify ISRC search failed:', await response.text());
    return null;
  }

  const data = await response.json();

  if (data.tracks && data.tracks.items.length > 0) {
    console.log(`Found track by ISRC ${isrc}: ${data.tracks.items[0].name} by ${data.tracks.items[0].artists[0].name}`);
    return data.tracks.items[0];
  }

  return null;
}

/**
 * Parse artist name to extract all artists (handles "ft.", "feat.", "&", etc.)
 */
function parseArtists(artistName: string): string[] {
  // Split on common delimiters for featured artists
  const delimiters = /\s+(?:ft\.?|feat\.?|featuring|&|,|\|)\s+/gi;
  const artists = artistName.split(delimiters).map(a => a.trim().toLowerCase());
  return artists;
}

/**
 * Check if track artists match the expected artist name (handles featured artists)
 */
function artistsMatch(trackArtists: Array<{name: string}>, expectedArtistName: string): boolean {
  const expectedArtists = parseArtists(expectedArtistName);
  const trackArtistNames = trackArtists.map(a => a.name.toLowerCase());

  // Check if all expected artists are present in the track's artists
  // This handles cases like "Dua Lipa ft. DaBaby" matching ["Dua Lipa", "DaBaby"]
  const allArtistsPresent = expectedArtists.every(expectedArtist =>
    trackArtistNames.some(trackArtist =>
      trackArtist.includes(expectedArtist) || expectedArtist.includes(trackArtist)
    )
  );

  return allArtistsPresent;
}

/**
 * Search for a track on Spotify
 */
async function searchTrack(trackName: string, artistName: string, accessToken: string): Promise<SpotifyTrack | null> {
  // Parse all artists from the artist name
  const allArtists = parseArtists(artistName);

  // Build search query with all artists for precise matching
  // For "Dua Lipa ft. DaBaby", this creates: track:"Levitating" artist:"dua lipa" artist:"dababy"
  const artistQueries = allArtists.map(artist => `artist:"${artist}"`).join(' ');
  const query = `track:"${trackName}" ${artistQueries}`;
  const encodedQuery = encodeURIComponent(query);

  const response = await fetch(
    `https://api.spotify.com/v1/search?q=${encodedQuery}&type=track&limit=20`,
    {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    }
  );

  if (!response.ok) {
    console.error('Spotify search failed:', await response.text());
    return null;
  }

  const data = await response.json();

  if (data.tracks && data.tracks.items.length > 0) {
    // Find all tracks that match the name and have all the expected artists
    const candidateMatches = data.tracks.items.filter((track: SpotifyTrack) => {
      // Check if track name matches (with or without feat. suffix)
      const trackNameLower = track.name.toLowerCase();
      const expectedNameLower = trackName.toLowerCase();
      const nameMatch = trackNameLower === expectedNameLower ||
                       trackNameLower.startsWith(expectedNameLower + ' (') ||
                       trackNameLower.startsWith(expectedNameLower + ' -');

      const artistMatch = artistsMatch(track.artists, artistName);
      return nameMatch && artistMatch;
    });

    if (candidateMatches.length > 0) {
      // Prefer tracks with featured artist info in the title when artist name has featured artists
      const hasFeaturedArtists = /\b(?:ft\.?|feat\.?|featuring)\b/i.test(artistName);

      if (hasFeaturedArtists) {
        const withFeatInTitle = candidateMatches.filter(track =>
          /\(feat\.?\s|featuring\s/i.test(track.name)
        );

        if (withFeatInTitle.length > 0) {
          const sorted = withFeatInTitle.sort((a: SpotifyTrack, b: SpotifyTrack) =>
            b.popularity - a.popularity
          );
          console.log(`Found ${withFeatInTitle.length} match(es) with feat. in title, returning most popular: ${sorted[0].name} by ${sorted[0].artists.map(a => a.name).join(', ')} (popularity: ${sorted[0].popularity})`);
          return sorted[0];
        }
      }

      // Otherwise return most popular match
      const sorted = candidateMatches.sort((a: SpotifyTrack, b: SpotifyTrack) =>
        b.popularity - a.popularity
      );
      console.log(`Found ${candidateMatches.length} match(es), returning most popular: ${sorted[0].name} by ${sorted[0].artists.map(a => a.name).join(', ')} (popularity: ${sorted[0].popularity})`);
      return sorted[0];
    }

    // Fallback: Return most popular result with matching name
    const nameMatches = data.tracks.items.filter((track: SpotifyTrack) =>
      track.name.toLowerCase() === trackName.toLowerCase()
    );

    if (nameMatches.length > 0) {
      const sorted = nameMatches.sort((a: SpotifyTrack, b: SpotifyTrack) =>
        b.popularity - a.popularity
      );
      console.log(`No exact match, using most popular: ${sorted[0].name} by ${sorted[0].artists.map(a => a.name).join(', ')}`);
      return sorted[0];
    }

    // Last resort: Return most popular overall
    const sorted = data.tracks.items.sort((a: SpotifyTrack, b: SpotifyTrack) =>
      b.popularity - a.popularity
    );
    return sorted[0];
  }

  return null;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { trackId, trackName, artistName, isrc } = await req.json() as TrackValidationRequest;

    // Get Spotify access token
    const tokenData = await getSpotifyToken();
    const accessToken = tokenData.access_token;

    let validatedTrack: SpotifyTrack | null = null;
    let method = 'unknown';

    // If we have a track ID, validate it first
    if (trackId) {
      validatedTrack = await validateTrackId(trackId, accessToken);
      method = 'validation';

      // Check if the validated track matches the expected name/artist
      if (validatedTrack && trackName && artistName) {
        const nameMatches = validatedTrack.name.toLowerCase() === trackName.toLowerCase();
        const artistMatches = artistsMatch(validatedTrack.artists, artistName);

        if (!nameMatches || !artistMatches) {
          console.log(`Track ID valid but metadata mismatch:`);
          console.log(`  Found: "${validatedTrack.name}" by ${validatedTrack.artists.map(a => a.name).join(', ')}`);
          console.log(`  Expected: "${trackName}" by ${artistName}`);
          console.log('  Searching for correct track...');

          // First try ISRC if available (most precise)
          if (isrc) {
            console.log(`  Trying ISRC: ${isrc}`);
            const isrcResult = await searchByISRC(isrc, accessToken);
            if (isrcResult) {
              // Verify the ISRC result matches the expected track
              const nameMatches = isrcResult.name.toLowerCase() === trackName.toLowerCase();
              const artistMatches = artistsMatch(isrcResult.artists, artistName);

              if (nameMatches && artistMatches) {
                validatedTrack = isrcResult;
                method = 'isrc_after_mismatch';
                console.log(`  ✓ Found via ISRC: ${isrcResult.name}`);
              } else {
                console.log(`  ✗ ISRC mismatch: found "${isrcResult.name}" but expected "${trackName}"`);
                console.log(`  ✗ ISRC is incorrect, falling back to name/artist search`);
              }
            }
          }

          // Fall back to name/artist search if ISRC didn't work or mismatched
          if (!validatedTrack || method === 'validation') {
            const searchResult = await searchTrack(trackName, artistName, accessToken);
            if (searchResult) {
              validatedTrack = searchResult;
              method = 'search_after_mismatch';
            }
          }
        }
      }
    }
    // If we have ISRC, use that first (most precise)
    else if (isrc) {
      validatedTrack = await searchByISRC(isrc, accessToken);
      method = 'isrc';

      // Fall back to name/artist if ISRC doesn't work
      if (!validatedTrack && trackName && artistName) {
        validatedTrack = await searchTrack(trackName, artistName, accessToken);
        method = 'search_after_isrc_fail';
      }
    }
    // Otherwise, search by name and artist
    else if (trackName && artistName) {
      validatedTrack = await searchTrack(trackName, artistName, accessToken);
      method = 'search';
    }
    else {
      return new Response(
        JSON.stringify({ error: 'Either trackId, isrc, or both trackName and artistName are required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Return the result
    if (validatedTrack) {
      // Get the best quality album art (usually middle size)
      const albumArt = validatedTrack.album.images.length > 1
        ? validatedTrack.album.images[1].url
        : validatedTrack.album.images[0]?.url;

      return new Response(
        JSON.stringify({
          success: true,
          method,
          track: {
            id: validatedTrack.id,
            name: validatedTrack.name,
            artistName: validatedTrack.artists[0].name,
            artists: validatedTrack.artists.map(a => a.name),
            albumArtUrl: albumArt,
            previewUrl: validatedTrack.preview_url,
            isrc: validatedTrack.external_ids?.isrc,
            popularity: validatedTrack.popularity,
            spotifyUrl: `https://open.spotify.com/track/${validatedTrack.id}`
          }
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Track not found',
          searched: { trackName, artistName }
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

  } catch (error) {
    console.error('Error in validate-track function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});