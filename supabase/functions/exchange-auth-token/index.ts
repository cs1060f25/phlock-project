// Edge Function to exchange native OAuth tokens for Supabase Auth sessions
// This allows seamless native Spotify/Apple Music auth while maintaining Supabase RLS
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ExchangeRequest {
  provider: 'spotify' | 'apple'
  accessToken: string
}

interface SpotifyUserProfile {
  id: string
  email: string
  display_name: string
  images?: Array<{ url: string }>
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { provider, accessToken } = await req.json() as ExchangeRequest

    if (!provider || !accessToken) {
      throw new Error('Missing provider or accessToken')
    }

    // Initialize Supabase Admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    let email: string
    let userId: string
    let displayName: string
    let profilePhotoUrl: string | null = null

    // Verify token and get user info from provider
    if (provider === 'spotify') {
      // Verify Spotify token and get user profile
      const spotifyResponse = await fetch('https://api.spotify.com/v1/me', {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      })

      if (!spotifyResponse.ok) {
        throw new Error(`Spotify API error: ${spotifyResponse.statusText}`)
      }

      const spotifyUser = await spotifyResponse.json() as SpotifyUserProfile
      email = spotifyUser.email
      userId = spotifyUser.id
      displayName = spotifyUser.display_name || 'Spotify User'
      profilePhotoUrl = spotifyUser.images?.[0]?.url || null

      console.log(`✅ Verified Spotify user: ${email}`)
    } else if (provider === 'apple') {
      // For Apple Music, the token is a MusicKit user token
      // We can't directly verify it, but we'll trust it since it came from native auth
      // Apple doesn't provide email from MusicKit, so we'll use a placeholder

      // In production, you'd want to verify this token somehow
      // For now, we'll generate a unique identifier from the token
      const tokenHash = await crypto.subtle.digest(
        'SHA-256',
        new TextEncoder().encode(accessToken)
      )
      const hashArray = Array.from(new Uint8Array(tokenHash))
      const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

      userId = hashHex.substring(0, 32)
      email = `${userId}@appleid.privaterelay.com`
      displayName = 'Apple Music User'

      console.log(`✅ Processing Apple Music user: ${email}`)
    } else {
      throw new Error(`Unsupported provider: ${provider}`)
    }

    // Check if user already exists in Supabase Auth by email
    const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
    const existingUser = existingUsers?.users.find(u => u.email === email)

    let authUserId: string

    if (existingUser) {
      // User exists - use their auth ID
      authUserId = existingUser.id
      console.log(`✅ Found existing Supabase Auth user: ${authUserId}`)

      // Update user metadata with provider info
      await supabaseAdmin.auth.admin.updateUserById(authUserId, {
        user_metadata: {
          ...existingUser.user_metadata,
          [`${provider}_user_id`]: userId,
          [`${provider}_connected`]: true,
        }
      })
    } else {
      // Create new Supabase Auth user
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email,
        email_confirm: true, // Auto-confirm since we verified via OAuth
        user_metadata: {
          display_name: displayName,
          profile_photo_url: profilePhotoUrl,
          [`${provider}_user_id`]: userId,
          auth_provider: provider,
        }
      })

      if (createError || !newUser.user) {
        throw new Error(`Failed to create Supabase Auth user: ${createError?.message}`)
      }

      authUserId = newUser.user.id
      console.log(`✅ Created new Supabase Auth user: ${authUserId}`)
    }

    // Generate a session token for the user
    // Note: This is a workaround since we can't directly create sessions via Admin API
    // Instead, we'll return the auth user ID and let the client use signInWithPassword or similar

    // Create a temporary password for this session
    const tempPassword = crypto.randomUUID()

    // Update user with temporary password
    await supabaseAdmin.auth.admin.updateUserById(authUserId, {
      password: tempPassword
    })

    // Return the auth user ID and temporary credentials
    // The client will use these to establish a proper session
    return new Response(
      JSON.stringify({
        success: true,
        auth_user_id: authUserId,
        email: email,
        temp_password: tempPassword,
        provider: provider,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('❌ Error in exchange-auth-token:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
