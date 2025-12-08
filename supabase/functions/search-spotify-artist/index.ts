// Supabase Edge Function to search for a Spotify artist and return their ID
// This keeps the Spotify client secret secure on the server side

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const SPOTIFY_CLIENT_ID = Deno.env.get('SPOTIFY_CLIENT_ID')
const SPOTIFY_CLIENT_SECRET = Deno.env.get('SPOTIFY_CLIENT_SECRET')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Helper to fetch with retry logic
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  maxRetries = 2
): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetch(url, options);

      // If rate limited, wait and retry
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get("Retry-After") || "1");
        console.log(`Rate limited, waiting ${retryAfter}s before retry...`);
        await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
        continue;
      }

      return response;
    } catch (error) {
      lastError = error;
      console.error(`Fetch attempt ${attempt + 1} failed:`, error);

      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 500 * (attempt + 1)));
      }
    }
  }

  throw lastError || new Error("All fetch attempts failed");
}

// Cache for Spotify access token
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getSpotifyToken(): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expiresAt - 60000) {
    return cachedToken.token;
  }

  if (!SPOTIFY_CLIENT_ID || !SPOTIFY_CLIENT_SECRET) {
    throw new Error("Spotify credentials not configured");
  }

  const tokenResponse = await fetchWithRetry(
    'https://accounts.spotify.com/api/token',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ' + btoa(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`)
      },
      body: 'grant_type=client_credentials'
    }
  );

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    console.error("Token error response:", errorText);
    throw new Error(`Spotify authentication failed (${tokenResponse.status})`);
  }

  const { access_token, expires_in } = await tokenResponse.json();

  cachedToken = {
    token: access_token,
    expiresAt: Date.now() + (expires_in * 1000),
  };

  return access_token;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    let requestBody: { artistName?: string };

    try {
      requestBody = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body" }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    const { artistName } = requestBody;

    if (!artistName || typeof artistName !== "string" || artistName.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'Artist name is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`🔍 Searching for artist: ${artistName}`)

    // Get Spotify access token (with caching and retry)
    const access_token = await getSpotifyToken();

    // Search for artist with retry
    const searchQuery = encodeURIComponent(artistName.trim())
    const searchResponse = await fetchWithRetry(
      `https://api.spotify.com/v1/search?q=${searchQuery}&type=artist&limit=20&market=US`,
      {
        headers: {
          'Authorization': `Bearer ${access_token}`
        }
      }
    )

    if (!searchResponse.ok) {
      const errorText = await searchResponse.text();
      console.error("Search error response:", errorText);

      if (searchResponse.status === 401) {
        cachedToken = null;
        throw new Error("Spotify session expired. Please try again.");
      } else if (searchResponse.status === 429) {
        throw new Error("Too many requests. Please wait a moment and try again.");
      } else if (searchResponse.status >= 500) {
        throw new Error("Spotify is temporarily unavailable. Please try again.");
      }

      throw new Error(`Search failed (${searchResponse.status})`);
    }

    const searchData = await searchResponse.json();

    // Handle case where artists might be undefined
    if (!searchData.artists?.items) {
      return new Response(
        JSON.stringify({ artists: [], spotifyId: null }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Return all artists (for search UI) or first artist only (for legacy compatibility)
    const artists = searchData.artists.items.map((artist: any) => ({
      id: artist.id,
      name: artist.name,
      images: artist.images || [],
      popularity: artist.popularity,
      followers: artist.followers?.total
    }))

    if (artists.length > 0) {
      console.log(`✅ Found ${artists.length} Spotify artists`)
      return new Response(
        JSON.stringify({
          artists: artists,
          // Legacy support: also return first artist as before
          spotifyId: artists[0].id,
          artistName: artists[0].name
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    } else {
      console.log(`⚠️ No Spotify artist found for: ${artistName}`)
      return new Response(
        JSON.stringify({ artists: [], spotifyId: null }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

  } catch (error) {
    console.error('❌ Error:', error)
    const message = error.message || "Something went wrong. Please try again.";
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
