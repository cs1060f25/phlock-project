import Foundation

/// Configuration for environment-specific values
/// TODO: Replace with your actual Supabase credentials
enum Config {
    // Supabase Configuration
    // Get these from your Supabase project settings
    static let supabaseURL = URL(string: "https://szfxnzsapojuemltjghb.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc"

    // Spotify Configuration
    // Get these from Spotify Developer Dashboard
    static let spotifyClientId = "68032dd9c4774f2b8f16ced8c77c9d25"
    static let spotifyRedirectURI = "phlock-spotify://callback"

    // Spotify API Scopes
    static let spotifyScopes = [
        "user-read-email",
        "user-read-private",
        "user-top-read",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-read-currently-playing",
        "user-read-recently-played"
    ]

    // Apple Music Configuration
    // Generated JWT token (valid until 2026-04-22)
    static let appleMusicDeveloperToken = "eyJhbGciOiJFUzI1NiIsImtpZCI6IlI0V1lEUDhENzIiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJZMjNSSlpNVjVNIiwiaWF0IjoxNzYxMzU3ODczLCJleHAiOjE3NzY5MDk4NzN9.jFaNSmBqza4HVJcK7BvJ8MIyyQcQAYJhZLzitfKv2jQ48XdRD45Fr3phlHJa1dxdJeqxa4agdHa0WQHHJftSgA"
}

// MARK: - Setup Instructions
/*
 To configure this app:

 1. Supabase Setup:
    - Go to your Supabase project settings
    - Copy the Project URL and anon/public key
    - Replace supabaseURL and supabaseAnonKey above

 2. Spotify Setup:
    - Go to https://developer.spotify.com/dashboard
    - Create a new app or use existing
    - Copy the Client ID
    - Add redirect URI: phlock-spotify://callback
    - Replace spotifyClientId above

 3. Apple Music Setup:
    - Go to Apple Developer Portal
    - Create a MusicKit Identifier
    - Generate a MusicKit Private Key
    - Create a developer token (JWT)
    - Replace appleMusicDeveloperToken above

 Note: In production, use a secure method to store these (e.g., Xcode build configurations,
 environment variables, or a secrets management system). Never commit actual keys to git!
 */
