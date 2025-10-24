import Foundation

/// Configuration for environment-specific values
/// TODO: Replace with your actual Supabase credentials
enum Config {
    // Supabase Configuration
    // Get these from your Supabase project settings
    static let supabaseURL = URL(string: "https://your-project.supabase.co")!
    static let supabaseAnonKey = "your-anon-key-here"

    // Spotify Configuration
    // Get these from Spotify Developer Dashboard
    static let spotifyClientId = "your-spotify-client-id"
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
    // Generate this from Apple Developer Portal
    static let appleMusicDeveloperToken = "your-apple-music-developer-token"
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
