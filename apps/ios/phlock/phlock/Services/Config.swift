import Foundation

/// Configuration for environment-specific values
/// Values are read from Info.plist which gets populated from xcconfig files at build time
/// This approach keeps secrets out of source code
enum Config {
    // MARK: - Supabase Configuration

    static var supabaseURL: URL {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not configured in xcconfig. See Configuration/Secrets.xcconfig.template")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured in xcconfig. See Configuration/Secrets.xcconfig.template")
        }
        return key
    }

    // MARK: - Spotify Configuration

    static var spotifyClientId: String {
        guard let clientId = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_ID"] as? String,
              !clientId.isEmpty else {
            fatalError("SPOTIFY_CLIENT_ID not configured in xcconfig. See Configuration/Secrets.xcconfig.template")
        }
        return clientId
    }

    static var spotifyRedirectURI: String {
        guard let uri = Bundle.main.infoDictionary?["SPOTIFY_REDIRECT_URI"] as? String,
              !uri.isEmpty else {
            return "phlock-spotify://callback" // Default fallback
        }
        return uri
    }

    /// Spotify API Scopes - these don't need to be secret
    static let spotifyScopes = [
        "user-read-email",
        "user-read-private",
        "user-top-read",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-read-currently-playing",
        "user-read-recently-played",
        "user-library-read",
        "user-library-modify"
    ]

    // MARK: - Apple Music Configuration

    static var appleMusicDeveloperToken: String {
        guard let token = Bundle.main.infoDictionary?["APPLE_MUSIC_DEVELOPER_TOKEN"] as? String,
              !token.isEmpty else {
            fatalError("APPLE_MUSIC_DEVELOPER_TOKEN not configured in xcconfig. See Configuration/Secrets.xcconfig.template")
        }
        return token
    }

    // MARK: - Google Sign-In Configuration

    static var googleClientId: String? {
        guard let clientId = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String,
              !clientId.isEmpty else {
            return nil // Optional - may not be configured yet
        }
        return clientId
    }
}

// MARK: - Setup Instructions
/*
 To configure this app:

 1. Copy Configuration/Secrets.xcconfig.template to:
    - Configuration/Debug.xcconfig (for development)
    - Configuration/Release.xcconfig (for production)

 2. Fill in your credentials in both files

 3. In Xcode, set the xcconfig files for each configuration:
    - Project > Info > Configurations
    - Debug: Debug.xcconfig
    - Release: Release.xcconfig

 4. Add Debug.xcconfig and Release.xcconfig to .gitignore

 IMPORTANT: Never commit xcconfig files with real credentials to git!
 Only commit the .template file.
 */
