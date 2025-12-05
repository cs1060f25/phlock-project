import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SPOTIFY_CLIENT_ID = Deno.env.get("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = Deno.env.get("SPOTIFY_CLIENT_SECRET");
// Developer's refresh token for accessing editorial playlists (stored in Supabase secrets)
const SPOTIFY_USER_REFRESH_TOKEN = Deno.env.get("SPOTIFY_USER_REFRESH_TOKEN");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Playlist types - using user-generated playlists that work in Dev Mode
type PlaylistType = "viral-hits" | "new-music-friday" | "todays-top-hits";

// User-generated playlist IDs (these work in Spotify Development Mode)
const PLAYLIST_IDS: Record<string, string> = {
  "new-music-friday": "5X8lN5fZSrLnXzFtDEUwb9",  // NPR Music's New Music Friday (82K followers)
  "viral-hits": "4SWt6k4KUSNzmgRtCTzOKM",        // TikTok 2025 (472K followers)
  "todays-top-hits": "6UeSakyzhiEt4NB3UAd6NQ",   // Billboard Hot 100 (1.7M followers)
};

interface PlaylistRequest {
  playlist: string;
  limit?: number;
}

// Token cache for user refresh token flow
let cachedToken: { token: string; expiry: number } | null = null;

async function getAccessToken(): Promise<string> {
  // Return cached token if still valid
  if (cachedToken && Date.now() < cachedToken.expiry) {
    console.log("Using cached Spotify token");
    return cachedToken.token;
  }

  console.log("Getting new Spotify token via refresh token...");
  console.log("SPOTIFY_CLIENT_ID:", SPOTIFY_CLIENT_ID ? "set" : "NOT SET");
  console.log("SPOTIFY_CLIENT_SECRET:", SPOTIFY_CLIENT_SECRET ? "set" : "NOT SET");
  console.log("SPOTIFY_USER_REFRESH_TOKEN:", SPOTIFY_USER_REFRESH_TOKEN ? "set" : "NOT SET");

  if (!SPOTIFY_USER_REFRESH_TOKEN) {
    throw new Error("SPOTIFY_USER_REFRESH_TOKEN not configured. Developer needs to authenticate and store refresh token.");
  }

  const credentials = btoa(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`);
  const response = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=refresh_token&refresh_token=${SPOTIFY_USER_REFRESH_TOKEN}`,
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Token refresh error:", response.status, errorText);
    throw new Error(`Failed to refresh Spotify token: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  console.log("Got Spotify token successfully via refresh");
  cachedToken = {
    token: data.access_token,
    // Expire 60 seconds early to be safe
    expiry: Date.now() + (data.expires_in - 60) * 1000,
  };
  return cachedToken.token;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { playlist, limit = 15 }: PlaylistRequest = await req.json();

    const validPlaylists = ["viral-hits", "new-music-friday", "todays-top-hits"];
    if (!validPlaylists.includes(playlist)) {
      return new Response(
        JSON.stringify({
          error: "Invalid playlist",
          validPlaylists,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const token = await getAccessToken();

    let tracks: any[] = [];

    // Check if we have a direct playlist ID for this playlist type
    const playlistId = PLAYLIST_IDS[playlist];

    if (playlistId) {
      // Fetch directly from the user-generated playlist (works in Dev Mode)
      const url = `https://api.spotify.com/v1/playlists/${playlistId}/tracks?limit=${limit}&market=US`;
      console.log(`Fetching playlist ${playlist} (ID: ${playlistId}):`, url);

      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${token}` },
      });

      console.log("Spotify response status:", response.status);

      if (!response.ok) {
        const errorText = await response.text();
        console.error("Spotify API error:", response.status, errorText);
        throw new Error(`Spotify API error: ${response.status} - ${errorText}`);
      }

      const data = await response.json();

      tracks = data.items
        ?.filter((item: any) => {
          if (!item.track || !item.track.album?.images?.length) return false;
          // For new-music-friday, exclude tracks from "All Songs Considered" album
          if (playlist === "new-music-friday" && item.track.album?.name === "All Songs Considered") {
            return false;
          }
          return true;
        })
        .slice(0, limit)
        .map((item: any) => ({
          id: item.track.id,
          name: item.track.name,
          artistName: item.track.artists?.[0]?.name || "Unknown Artist",
          previewUrl: item.track.preview_url,
          albumArtUrl: item.track.album.images[0].url,
          isrc: item.track.external_ids?.isrc,
          spotifyId: item.track.id,
        })) || [];

      console.log(`Got ${tracks.length} tracks from playlist`);
    } else {
      // Fallback: For todays-top-hits (no playlist ID), use search API with popular artists
      const searchQueries: Record<string, string[]> = {
        "todays-top-hits": ["Beyonce", "Kendrick Lamar", "Ariana Grande", "Post Malone", "Billie Eilish"],
      };

      const artists = searchQueries[playlist] || ["Drake", "Taylor Swift"];
      const allTracks: any[] = [];

      for (const artist of artists) {
        const url = `https://api.spotify.com/v1/search?q=artist:${encodeURIComponent(artist)}&type=track&limit=4&market=US`;
        console.log("Searching tracks for artist:", artist);

        const response = await fetch(url, {
          headers: { Authorization: `Bearer ${token}` },
        });

        if (response.ok) {
          const data = await response.json();
          const artistTracks = data.tracks?.items
            ?.filter((track: any) => track && track.album?.images?.length > 0)
            .map((track: any) => ({
              id: track.id,
              name: track.name,
              artistName: track.artists?.[0]?.name || "Unknown Artist",
              previewUrl: track.preview_url,
              albumArtUrl: track.album.images[0].url,
              isrc: track.external_ids?.isrc,
              spotifyId: track.id,
            })) || [];
          allTracks.push(...artistTracks);
        }
      }

      tracks = allTracks
        .sort(() => Math.random() - 0.5)
        .slice(0, limit);
    }

    return new Response(JSON.stringify({ tracks }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
