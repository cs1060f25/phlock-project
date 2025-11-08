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
 * Search for a track on Spotify
 */
async function searchTrack(trackName: string, artistName: string, accessToken: string): Promise<SpotifyTrack | null> {
  // Build search query
  const query = `track:"${trackName}" artist:"${artistName}"`;
  const encodedQuery = encodeURIComponent(query);

  const response = await fetch(
    `https://api.spotify.com/v1/search?q=${encodedQuery}&type=track&limit=10`,
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
    // Try to find exact match
    const exactMatch = data.tracks.items.find((track: SpotifyTrack) => {
      const nameMatch = track.name.toLowerCase() === trackName.toLowerCase();
      const artistMatch = track.artists.some(artist =>
        artist.name.toLowerCase() === artistName.toLowerCase() ||
        artistName.toLowerCase().includes(artist.name.toLowerCase())
      );
      return nameMatch && artistMatch;
    });

    if (exactMatch) {
      return exactMatch;
    }

    // Return most popular result if no exact match
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
    const { trackId, trackName, artistName } = await req.json() as TrackValidationRequest;

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
        const artistMatches = validatedTrack.artists.some(artist =>
          artistName.toLowerCase().includes(artist.name.toLowerCase())
        );

        if (!nameMatches || !artistMatches) {
          console.log('Track ID valid but metadata mismatch, searching for correct track...');
          // Track ID is valid but doesn't match - search for the correct one
          const searchResult = await searchTrack(trackName, artistName, accessToken);
          if (searchResult) {
            validatedTrack = searchResult;
            method = 'search_after_mismatch';
          }
        }
      }
    }
    // Otherwise, search by name and artist
    else if (trackName && artistName) {
      validatedTrack = await searchTrack(trackName, artistName, accessToken);
      method = 'search';
    }
    else {
      return new Response(
        JSON.stringify({ error: 'Either trackId or both trackName and artistName are required' }),
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