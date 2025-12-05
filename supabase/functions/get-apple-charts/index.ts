import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const APPLE_MUSIC_DEVELOPER_TOKEN = Deno.env.get("APPLE_MUSIC_DEVELOPER_TOKEN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ChartsRequest {
  chartType: "top-songs" | "trending";
  limit?: number;
  storefront?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { chartType, limit = 15, storefront = "us" }: ChartsRequest = await req.json();

    console.log(`Fetching Apple Music charts: ${chartType}, limit: ${limit}, storefront: ${storefront}`);

    if (!APPLE_MUSIC_DEVELOPER_TOKEN) {
      throw new Error("APPLE_MUSIC_DEVELOPER_TOKEN not configured");
    }

    // Apple Music only has 'most-played' as a reliable chart endpoint
    // For both 'top-songs' and 'trending', we use the same endpoint but can shuffle for variety
    const url = `https://api.music.apple.com/v1/catalog/${storefront}/charts?types=songs&chart=most-played&limit=${Math.min(limit * 2, 50)}`;
    const shouldShuffle = chartType === "trending"; // Shuffle for viral/trending to show different songs

    console.log("Apple Music API URL:", url);

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${APPLE_MUSIC_DEVELOPER_TOKEN}`,
      },
    });

    console.log("Apple Music response status:", response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Apple Music API error:", response.status, errorText);
      throw new Error(`Apple Music API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();

    // Transform Apple Music response to our track format
    // Apple Music returns charts in results.songs[0].data array
    let songs = data.results?.songs?.[0]?.data || [];
    console.log(`Got ${songs.length} songs from Apple Music`);

    // For trending/viral, shuffle the results to show variety
    if (shouldShuffle && songs.length > 0) {
      songs = [...songs].sort(() => Math.random() - 0.5);
    }

    const tracks = songs.slice(0, limit).map((song: any) => ({
      id: song.id,
      name: song.attributes?.name || "Unknown Track",
      artistName: song.attributes?.artistName || "Unknown Artist",
      previewUrl: song.attributes?.previews?.[0]?.url || null,
      albumArtUrl: song.attributes?.artwork?.url
        ?.replace("{w}", "300")
        ?.replace("{h}", "300") || null,
      isrc: song.attributes?.isrc || null,
      appleMusicId: song.id,
      durationMs: song.attributes?.durationInMillis || null,
      albumName: song.attributes?.albumName || null,
    }));

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
