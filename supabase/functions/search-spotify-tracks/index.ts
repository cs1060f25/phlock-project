import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SPOTIFY_CLIENT_ID = Deno.env.get("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = Deno.env.get("SPOTIFY_CLIENT_SECRET");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface TrackSearchRequest {
  query: string;
  limit?: number;
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
        // Exponential backoff: 500ms, 1000ms
        await new Promise(resolve => setTimeout(resolve, 500 * (attempt + 1)));
      }
    }
  }

  throw lastError || new Error("All fetch attempts failed");
}

// Cache for Spotify access token (reuse within function lifecycle)
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getSpotifyToken(): Promise<string> {
  // Return cached token if still valid (with 60s buffer)
  if (cachedToken && Date.now() < cachedToken.expiresAt - 60000) {
    return cachedToken.token;
  }

  if (!SPOTIFY_CLIENT_ID || !SPOTIFY_CLIENT_SECRET) {
    throw new Error("Spotify credentials not configured");
  }

  const tokenResponse = await fetchWithRetry(
    "https://accounts.spotify.com/api/token",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Authorization: `Basic ${btoa(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`)}`,
      },
      body: "grant_type=client_credentials",
    }
  );

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    console.error("Token error response:", errorText);
    throw new Error(`Spotify authentication failed (${tokenResponse.status})`);
  }

  const { access_token, expires_in } = await tokenResponse.json();

  // Cache the token
  cachedToken = {
    token: access_token,
    expiresAt: Date.now() + (expires_in * 1000),
  };

  return access_token;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let requestBody: TrackSearchRequest;

    try {
      requestBody = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON in request body" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { query, limit = 20 } = requestBody;

    if (!query || typeof query !== "string" || query.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Query parameter is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Get Spotify access token (with caching and retry)
    const access_token = await getSpotifyToken();

    // Search for tracks with retry
    const searchUrl = new URL("https://api.spotify.com/v1/search");
    searchUrl.searchParams.append("q", query.trim());
    searchUrl.searchParams.append("type", "track");
    searchUrl.searchParams.append("limit", Math.min(Math.max(1, limit), 50).toString());
    searchUrl.searchParams.append("market", "US");

    const searchResponse = await fetchWithRetry(searchUrl.toString(), {
      headers: {
        Authorization: `Bearer ${access_token}`,
      },
    });

    if (!searchResponse.ok) {
      const errorText = await searchResponse.text();
      console.error("Search error response:", errorText);

      // Return specific error messages
      if (searchResponse.status === 401) {
        // Token expired, clear cache and suggest retry
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

    // Handle case where tracks might be undefined or empty
    if (!searchData.tracks?.items) {
      return new Response(JSON.stringify({ tracks: [] }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Transform Spotify response to our format
    const tracks = searchData.tracks.items.map((track: any) => ({
      id: track.id,
      name: track.name,
      artists: track.artists.map((artist: any) => ({
        name: artist.name,
      })),
      album: {
        images: track.album.images,
      },
      preview_url: track.preview_url,
      external_ids: track.external_ids,
      popularity: track.popularity,
    }));

    return new Response(JSON.stringify({ tracks }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);

    // Provide user-friendly error messages
    const message = error.message || "Something went wrong. Please try again.";

    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
