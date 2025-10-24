# Phlock iOS App Setup Guide

## Step 1: Create Xcode Project

1. **Open Xcode** (version 15.0 or later required)

2. **Create New Project:**
   - File → New → Project
   - Choose "iOS" → "App"
   - Click "Next"

3. **Project Configuration:**
   - **Product Name:** `Phlock`
   - **Team:** Select your Apple Developer account
   - **Organization Identifier:** `com.phlock`
   - **Bundle Identifier:** Will auto-generate as `com.phlock.Phlock`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (we'll use Supabase)
   - **Include Tests:** ✅ (optional but recommended)
   - Click "Next"

4. **Save Location:**
   - Navigate to: `/Users/woonlee/Desktop/Phlock/phlock-dev/apps/ios/`
   - **IMPORTANT:** Uncheck "Create Git repository" (we already have one)
   - Click "Create"

## Step 2: Configure Project Settings

### Target Settings

1. Open project navigator (⌘+1)
2. Select "Phlock" project (blue icon)
3. Select "Phlock" target
4. **General Tab:**
   - **Minimum Deployments:** iOS 17.0
   - **Supported Destinations:** iPhone only (for now)

### Info.plist Configuration

1. Select "Info" tab in target settings
2. Add the following keys:

   **For Spotify OAuth:**
   - **URL Types** → Add URL Type:
     - **Identifier:** `com.phlock.spotify`
     - **URL Schemes:** `phlock-spotify` (you'll configure this with Spotify app)

   **For Apple Music:**
   - **Privacy - Media Library Usage Description:**
     - Value: "Phlock needs access to your music library to connect with Apple Music"
   - **Privacy - Music Usage Description:**
     - Value: "Phlock uses your Apple Music subscription to play previews and share music with friends"

## Step 3: Add Swift Package Dependencies

1. **File → Add Package Dependencies**

2. **Add Supabase Swift:**
   - URL: `https://github.com/supabase/supabase-swift`
   - Dependency Rule: Up to Next Major Version → 2.0.0
   - Add to Target: Phlock
   - Select:
     - ✅ Supabase
     - ✅ Auth
     - ✅ PostgREST
     - ✅ Storage
     - ✅ Realtime (optional for now)

3. **Add KeychainAccess:**
   - URL: `https://github.com/kishikawakatsumi/KeychainAccess`
   - Dependency Rule: Up to Next Major Version → 4.0.0
   - Add to Target: Phlock

4. **Wait for packages to resolve** (may take a minute)

## Step 4: Initial Project Structure

Once the Xcode project is created, we'll add this structure:

```
Phlock/
├── PhlockApp.swift           # App entry point
├── Models/
│   ├── User.swift
│   ├── Friendship.swift
│   └── PlatformToken.swift
├── Services/
│   ├── SupabaseClient.swift
│   ├── AuthService.swift
│   ├── SpotifyService.swift
│   └── AppleMusicService.swift
├── Views/
│   ├── Auth/
│   │   ├── WelcomeView.swift
│   │   ├── PlatformSelectionView.swift
│   │   └── ProfileSetupView.swift
│   ├── Main/
│   │   └── MainView.swift
│   └── Components/
│       ├── PhlockButton.swift
│       ├── PhlockTextField.swift
│       └── LoadingView.swift
├── ViewModels/
│   └── AuthenticationState.swift
└── Assets.xcassets
```

## Step 5: Environment Configuration

1. Create `.env` file (not tracked in git):
   ```bash
   SUPABASE_URL=your_supabase_url_here
   SUPABASE_ANON_KEY=your_supabase_anon_key_here
   ```

2. Add to `.gitignore`:
   ```
   .env
   *.xcuserdata
   xcuserdata/
   ```

## Step 6: Developer Account Setup

### Spotify Developer Account

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app: "Phlock"
3. Note the **Client ID**
4. Add Redirect URI: `phlock-spotify://callback`
5. Request scopes:
   - `user-read-email`
   - `user-read-private`
   - `user-top-read`
   - `playlist-read-private`
   - `user-read-currently-playing`
   - `user-read-recently-played`

### Apple Music Developer

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Certificates, Identifiers & Profiles
3. Identifiers → Media IDs → Create new MusicKit identifier
4. Generate MusicKit private key
5. Download and store securely

## Next Steps

Once you've completed these setup steps, let me know and I'll:
1. Create the Swift service files
2. Build the UI components
3. Implement the auth flows
4. Test Spotify and Apple Music integration

---

**Ready to proceed?** After creating the Xcode project, return to Claude Code and we'll start building the app structure.
