// Supabase Edge Function to browse popular artists by genre using Spotify API
// Uses genre-based search to find popular artists in a specific genre

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

interface SpotifyArtist {
  id: string
  name: string
  images?: Array<{
    url: string
    height: number
    width: number
  }>
  popularity: number
  followers?: {
    total: number
  }
  genres?: string[]
}

interface SpotifySearchResponse {
  artists: {
    items: SpotifyArtist[]
  }
}

// Curated genre mappings - these are Spotify's genre seeds that work well
const GENRE_MAPPINGS: Record<string, string[]> = {
  'pop': ['pop'],
  'hip-hop': ['hip-hop', 'rap'],
  'r&b': ['r-n-b'],
  'rock': ['rock'],
  'indie': ['indie', 'indie-pop', 'alt-rock'],
  'electronic': ['electronic', 'edm', 'house'],
  'jazz': ['jazz'],
  'classical': ['classical'],
  'country': ['country'],
  'latin': ['latin'],
  'k-pop': ['k-pop'],
  'soul': ['soul'],
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { genre, limit = 20 } = await req.json()

    if (!genre) {
      return new Response(
        JSON.stringify({ error: 'Genre is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log(`🎵 Browsing artists for genre: ${genre}`)

    // Get Spotify credentials
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

    // Get access token
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

    // Build genre search query
    // Spotify search supports "genre:xxx" queries
    const genreKey = genre.toLowerCase()
    const genreTerms = GENRE_MAPPINGS[genreKey] || [genreKey]

    // Search for artists in this genre
    // We use multiple genre terms and combine results for better coverage
    const allArtists: Map<string, SpotifyArtist> = new Map()

    for (const term of genreTerms) {
      const searchQuery = encodeURIComponent(`genre:${term}`)
      const searchResponse = await fetch(
        `https://api.spotify.com/v1/search?q=${searchQuery}&type=artist&limit=${Math.min(limit, 50)}`,
        {
          headers: {
            'Authorization': `Bearer ${tokenData.access_token}`
          }
        }
      )

      if (searchResponse.ok) {
        const searchData: SpotifySearchResponse = await searchResponse.json()
        for (const artist of searchData.artists.items) {
          // Use map to dedupe artists
          if (!allArtists.has(artist.id)) {
            allArtists.set(artist.id, artist)
          }
        }
      }
    }

    // Convert to array and sort by popularity
    const artists = Array.from(allArtists.values())
      .sort((a, b) => (b.popularity || 0) - (a.popularity || 0))
      .slice(0, limit)
      .map(artist => ({
        id: artist.id,
        name: artist.name,
        imageUrl: artist.images?.[0]?.url || null,
        popularity: artist.popularity,
        followerCount: artist.followers?.total,
        genres: artist.genres || []
      }))

    console.log(`✅ Found ${artists.length} artists for genre: ${genre}`)

    return new Response(
      JSON.stringify({
        genre: genre,
        artists: artists
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

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
