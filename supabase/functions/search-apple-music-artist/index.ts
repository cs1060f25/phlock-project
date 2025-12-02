// Supabase Edge Function to search for an Apple Music artist and return their ID
// Uses the Apple Music Catalog API with developer token for reliable results

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AppleMusicSearchResponse {
  results: {
    artists?: {
      data: Array<{
        id: string
        attributes: {
          name: string
          url?: string
        }
      }>
    }
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

    console.log(`🔍 Searching Apple Music for artist: ${artistName}`)

    // Get Apple Music developer token from environment
    const developerToken = Deno.env.get('APPLE_MUSIC_DEVELOPER_TOKEN')

    if (!developerToken) {
      console.error('❌ Apple Music developer token not configured')
      return new Response(
        JSON.stringify({ error: 'Apple Music developer token not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Search Apple Music Catalog API for artists
    const searchQuery = encodeURIComponent(artistName)
    const searchResponse = await fetch(
      `https://api.music.apple.com/v1/catalog/us/search?term=${searchQuery}&types=artists&limit=5`,
      {
        headers: {
          'Authorization': `Bearer ${developerToken}`,
          'Content-Type': 'application/json'
        }
      }
    )

    if (!searchResponse.ok) {
      const errorText = await searchResponse.text()
      console.error(`❌ Apple Music API error: ${searchResponse.status} - ${errorText}`)

      // If token is expired or invalid, return specific error
      if (searchResponse.status === 401 || searchResponse.status === 403) {
        return new Response(
          JSON.stringify({ error: 'Apple Music developer token may be expired' }),
          {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      return new Response(
        JSON.stringify({ error: 'Apple Music search failed' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const searchData: AppleMusicSearchResponse = await searchResponse.json()
    const artists = searchData.results?.artists?.data || []

    if (artists.length > 0) {
      const firstArtist = artists[0]
      console.log(`✅ Found Apple Music artist: ${firstArtist.attributes.name} (ID: ${firstArtist.id})`)

      return new Response(
        JSON.stringify({
          appleMusicId: firstArtist.id,
          artistName: firstArtist.attributes.name,
          // Also return all artists for potential future use
          artists: artists.map(a => ({
            id: a.id,
            name: a.attributes.name,
            url: a.attributes.url
          }))
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    } else {
      console.log(`⚠️ No Apple Music artist found for: ${artistName}`)
      return new Response(
        JSON.stringify({ appleMusicId: null, artists: [] }),
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
