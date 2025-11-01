import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const SPOTIFY_CLIENT_ID = Deno.env.get("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = Deno.env.get("SPOTIFY_CLIENT_SECRET");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ArtistTopTracksRequest {
  artistId: string;
  market?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { artistId, market = "US" }: ArtistTopTracksRequest = await req.json();

    if (!artistId) {
      return new Response(
        JSON.stringify({ error: "Artist ID is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`🎵 Fetching top tracks for artist: ${artistId}`);

    // Get Spotify access token using client credentials flow
    const tokenResponse = await fetch(
      "https://accounts.spotify.com/api/token",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Authorization: `Basic ${btoa(
            `${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`
          )}`,
        },
        body: "grant_type=client_credentials",
      }
    );

    if (!tokenResponse.ok) {
      throw new Error("Failed to get Spotify access token");
    }

    const { access_token } = await tokenResponse.json();

    // Get artist's top tracks
    const topTracksUrl = `https://api.spotify.com/v1/artists/${artistId}/top-tracks?market=${market}`;
    const topTracksResponse = await fetch(topTracksUrl, {
      headers: {
        Authorization: `Bearer ${access_token}`,
      },
    });

    if (!topTracksResponse.ok) {
      throw new Error("Failed to fetch artist top tracks");
    }

    const topTracksData = await topTracksResponse.json();

    // Transform Spotify response to our format
    const tracks = topTracksData.tracks.map((track: any) => ({
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
    }));

    console.log(`✅ Found ${tracks.length} top tracks`);

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
