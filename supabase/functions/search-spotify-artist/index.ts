// Supabase Edge Function to search for a Spotify artist and return their ID
// This keeps the Spotify client secret secure on the server side

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SpotifyTokenResponse {
  access_token: string
  token_type: string
  expires_in: number
}

interface SpotifyArtistSearchResponse {
  artists: {
    items: Array<{
      id: string
      name: string
      images?: Array<{
        url: string
        height: number
        width: number
      }>
    }>
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get artist name from request
    const { artistName } = await req.json()

    if (!artistName) {
      return new Response(
        JSON.stringify({ error: 'Artist name is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`🔍 Searching for artist: ${artistName}`)

    // Get Spotify credentials from environment variables
    const clientId = Deno.env.get('SPOTIFY_CLIENT_ID')
    const clientSecret = Deno.env.get('SPOTIFY_CLIENT_SECRET')

    if (!clientId || !clientSecret) {
      console.error('❌ Spotify credentials not configured')
      return new Response(
        JSON.stringify({ error: 'Spotify credentials not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Step 1: Get access token using client credentials flow
    const tokenResponse = await fetch('https://accounts.spotify.com/api/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic ' + btoa(`${clientId}:${clientSecret}`)
      },
      body: 'grant_type=client_credentials'
    })

    if (!tokenResponse.ok) {
      console.error('❌ Failed to get Spotify token')
      return new Response(
        JSON.stringify({ error: 'Failed to authenticate with Spotify' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const tokenData: SpotifyTokenResponse = await tokenResponse.json()
    console.log('✅ Got Spotify access token')

    // Step 2: Search for artist
    const searchQuery = encodeURIComponent(artistName)
    const searchResponse = await fetch(
      `https://api.spotify.com/v1/search?q=${searchQuery}&type=artist&limit=20`,
      {
        headers: {
          'Authorization': `Bearer ${tokenData.access_token}`
        }
      }
    )

    if (!searchResponse.ok) {
      console.error('❌ Spotify search failed')
      return new Response(
        JSON.stringify({ error: 'Spotify search failed' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const searchData: SpotifyArtistSearchResponse = await searchResponse.json()

    // Step 3: Return all artists (for search UI) or first artist only (for legacy compatibility)
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
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
