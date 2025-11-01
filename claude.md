# Phlock - Social Music Discovery Platform

## Project Overview

Phlock is a social music discovery app that enables users to share songs with friends across Spotify and Apple Music platforms. The core concept is to create viral song spread tracking, showing how music propagates through friend networks with rich social interactions and gamification.

**Vision:** Differentiate from Spotify/Apple Music by focusing on:
- Viral tracking (see how songs spread through your network)
- Social reactions and engagement mechanics
- Real-time interactive experiences (listening parties, timestamped reactions)
- Gamification and friendly competition

**Current Status:** Phase 1 - Social MVP
- Native iOS app with SwiftUI
- Supabase backend with PostgreSQL
- OAuth authentication with Spotify and Apple Music
- Basic sharing, friends, and feed functionality working

## Tech Stack

### Frontend
- **iOS App:** SwiftUI + Swift 5
- **Platform:** iOS 15+
- **Architecture:** MVVM pattern with ObservableObject view models
- **Music Integration:**
  - Spotify Web API
  - Apple Music API (MusicKit)
- **Authentication:** Native OAuth with Supabase session exchange

### Backend
- **Database:** PostgreSQL (via Supabase)
- **Auth:** Supabase Auth with custom OAuth flow
- **Storage:** Supabase Storage (profile photos)
- **Real-time:** Supabase Realtime (planned for viral tracking, reactions)
- **Edge Functions:** TypeScript/Deno
  - `exchange-auth-token`: Native OAuth to Supabase session conversion
  - `search-spotify-tracks`: Spotify search with client secret
  - `search-spotify-artist`: Artist search
  - `get-artist-top-tracks`: Top tracks for artist

### Infrastructure
- **Monorepo Structure:** Turborepo
- **Deployment:** Supabase Cloud
- **Version Control:** Git (branch: `phase/1-social-mvp`)

## Project Structure

```
phlock-dev/
├── apps/
│   └── ios/
│       └── phlock/              # iOS app
│           ├── phlock/
│           │   ├── Models/      # Data models (User, Share, Friendship, etc.)
│           │   ├── Services/    # Business logic services
│           │   ├── ViewModels/  # State management
│           │   ├── Views/       # SwiftUI views
│           │   │   ├── Auth/    # Authentication flow
│           │   │   ├── Main/    # Main app views (Feed, Discover, Friends, Profile)
│           │   │   └── Components/ # Reusable UI components
│           │   ├── Assets.xcassets/
│           │   ├── Fonts/       # Custom fonts (Nunito Sans)
│           │   └── Extensions/  # Swift extensions
│           └── phlock.xcodeproj/
├── packages/
│   └── database/
│       └── migrations/          # SQL migrations
├── supabase/
│   ├── functions/               # Edge Functions
│   │   ├── exchange-auth-token/
│   │   ├── search-spotify-tracks/
│   │   ├── search-spotify-artist/
│   │   └── get-artist-top-tracks/
│   └── seed/                    # SQL seed data
│       ├── 001_initial_schema.sql
│       ├── 002_dummy_users.sql
│       ├── 003_dummy_data_for_current_user.sql
│       ├── 004_link_existing_dummy_data.sql
│       ├── 005_fix_rls_for_friends.sql
│       └── 006_force_fix_rls.sql
├── docs/
│   └── FEATURE_ROADMAP.md      # Future features and implementation plan
├── AUTHSERVICE_V2_IMPLEMENTATION.md
├── SUPABASE_AUTH_MIGRATION_GUIDE.md
└── README.md
```

## Database Schema

### Core Tables

#### `users`
```sql
- id (uuid, primary key)
- auth_user_id (uuid, references auth.users) -- Supabase Auth user
- email (text, unique)
- display_name (text)
- platform_type (text) -- 'spotify' or 'apple_music'
- platform_user_id (text)
- profile_photo_url (text)
- spotify_id (text)
- apple_music_id (text)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### `friendships`
```sql
- id (uuid, primary key)
- user_id_1 (uuid, references users) -- Requester
- user_id_2 (uuid, references users) -- Recipient
- status (text) -- 'pending', 'accepted', 'rejected'
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### `shares`
```sql
- id (uuid, primary key)
- sender_id (uuid, references users)
- recipient_id (uuid, references users)
- track_id (text) -- Spotify or Apple Music track ID
- track_name (text)
- artist_name (text)
- album_art_url (text)
- preview_url (text)
- message (text) -- Optional message with share
- status (text) -- 'sent', 'played', 'saved'
- created_at (timestamptz)
- played_at (timestamptz)
- saved_at (timestamptz)
```

#### `platform_tokens` (encrypted)
```sql
- id (uuid, primary key)
- user_id (uuid, references users)
- platform_type (text)
- access_token (text, encrypted)
- refresh_token (text, encrypted)
- expires_at (timestamptz)
- created_at (timestamptz)
- updated_at (timestamptz)
```

### Row Level Security (RLS)
All tables have RLS enabled with policies based on `auth.uid()`:
- Users can view all profiles (for discovery)
- Users can view their own shares and friend activity
- Users can create/update/delete their own data
- Users can view/manage their own friendships

## Key Services (iOS)

### AuthService_v2.swift
Handles authentication flow:
- Native Spotify OAuth → Exchange token via Edge Function → Supabase session
- Native Apple Music OAuth → Exchange token via Edge Function → Supabase session
- Token refresh and session management
- Profile creation/updates
- Profile photo uploads

**Key Methods:**
- `signInWithSpotify()` - Spotify OAuth flow
- `signInWithAppleMusic()` - Apple Music OAuth flow
- `exchangeNativeToken()` - Convert platform token to Supabase session
- `signOut()` - Clear session and tokens

### SpotifyService.swift
Spotify API integration:
- Token management (from encrypted storage)
- Search tracks/artists
- Get user's top artists
- Fetch track details

### AppleMusicService.swift
Apple Music API integration:
- MusicKit authorization
- Search tracks by name/artist/ISRC
- Cross-platform matching (ISRC-based)

### UserService.swift
User and friendship management:
- Search users by display name
- Send/accept/reject friend requests
- Get friends list
- Get pending requests
- Check friendship status

### PhlockService.swift
Share management:
- Send shares to friends
- Get received/sent shares
- Get feed (friend activity)
- Update share status (played, saved)

### PlaybackService.swift
Audio playback:
- Play preview URLs (30s clips)
- Fallback to Apple Music if no preview URL
- Playback controls (play/pause/seek)
- Audio session management

### SearchService.swift
Unified search across platforms:
- Search tracks/artists based on user's platform
- Get artist top tracks
- Result formatting (MusicItem model)

## Key Models

### User
```swift
struct User: Codable, Identifiable {
    let id: UUID
    let authUserId: UUID
    let email: String
    let displayName: String
    let platformType: PlatformType
    let platformUserId: String
    let profilePhotoUrl: String?
    let spotifyId: String?
    let appleMusicId: String?
}
```

### Share
```swift
struct Share: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let trackId: String
    let trackName: String
    let artistName: String
    let albumArtUrl: String?
    let previewUrl: String?
    let message: String?
    let status: ShareStatus
    let createdAt: Date
    let playedAt: Date?
    let savedAt: Date?
    var sender: User?
    var recipient: User?
}
```

### Friendship
```swift
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId1: UUID
    let userId2: UUID
    let status: FriendshipStatus
    let createdAt: Date
}
```

### MusicItem
```swift
struct MusicItem: Identifiable, Equatable {
    let id: String
    let name: String
    let artistName: String?
    let previewUrl: String?
    let albumArtUrl: String?
    let isrc: String?
    let playedAt: Date?
    let spotifyId: String?
    let appleMusicId: String?
    let popularity: Int?
    let followerCount: Int?
}
```

## Main Views

### Authentication Flow
1. **WelcomeView** - Landing page with platform selection
2. **PlatformSelectionView** - Choose Spotify or Apple Music
3. **ProfileSetupView** - Set display name and profile photo
4. **SplashScreenView** - Loading screen during auth

### Main App (Tab Bar)
1. **FeedView** - See friend activity and shares
2. **DiscoverView** - Search and discover music
3. **MyPhlocksView** - View viral spread of your shares (placeholder)
4. **FriendsView** - Manage friends and requests
5. **ProfileView** - User profile and settings

### Detail Views
- **ArtistDetailView** - Artist info with top tracks and search
- **UserProfileView** - View friend profiles
- **PhlockDetailView** - Viral spread visualization (placeholder)
- **EditProfileView** - Edit profile info

## Design System

### Typography
- **Font:** Nunito Sans (custom)
- **Usage:** `.nunitoSans(size:weight:)` extension
- **Weights:** Regular, SemiBold, Bold, ExtraBold

### Colors
- Adaptive (light/dark mode support)
- Primary: Dynamic based on color scheme
- Logo: Geometric network visualization

### Components
- **PhlockButton** - Styled button component
- **PhlockTextField** - Styled text input
- **LoadingView** - Loading indicator
- **GeometricLogoView** - Network visualization logo
- **MiniPlayerView** - Bottom music player
- **FullScreenPlayerView** - Expanded player modal

## Authentication Flow

### Hybrid Native OAuth + Supabase
1. User initiates login with Spotify/Apple Music
2. Native platform OAuth (ASWebAuthenticationSession for Spotify, MusicKit for Apple)
3. Receive platform access token
4. Call Edge Function `exchange-auth-token` with platform token
5. Edge Function verifies token with platform API
6. Edge Function creates/finds Supabase Auth user
7. Edge Function returns temporary credentials
8. Client establishes Supabase session with credentials
9. Store encrypted platform token in database
10. Fetch/create user profile

**Key Benefit:** Native UX while maintaining Supabase session for RLS policies

## Environment & Configuration

### Required Environment Variables (.env.local)
```
SUPABASE_URL=<your-supabase-url>
SUPABASE_ANON_KEY=<your-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
SPOTIFY_CLIENT_ID=<your-spotify-client-id>
SPOTIFY_CLIENT_SECRET=<your-spotify-client-secret>
```

### iOS Config (Config.swift)
```swift
static let supabaseURL = "https://your-project.supabase.co"
static let supabaseAnonKey = "your-anon-key"
static let spotifyClientId = "your-client-id"
static let spotifyRedirectUri = "phlock://spotify-callback"
static let appleMusicDevToken = "your-apple-music-token" // Optional
```

## Development Setup

### Prerequisites
- Xcode 15+
- iOS 15+ deployment target
- Supabase project
- Spotify Developer account (for OAuth app)
- Apple Developer account (for Apple Music)

### Running the iOS App
1. Open `apps/ios/phlock/phlock.xcodeproj` in Xcode
2. Update `Config.swift` with your credentials
3. Build and run on simulator or device
4. Sign in with Spotify or Apple Music

### Database Setup
1. Run migrations in order from `packages/database/migrations/`
2. Run seed files in `supabase/seed/` for dummy data
3. Ensure RLS policies are applied (use `006_force_fix_rls.sql`)

### Edge Functions Development
```bash
cd supabase/functions
supabase functions serve <function-name>
```

## Current Features (Working)

✅ Native Spotify OAuth authentication
✅ Native Apple Music OAuth authentication
✅ User profile creation and editing
✅ Profile photo upload
✅ Friend search and discovery
✅ Send/accept/reject friend requests
✅ View friends list and pending requests
✅ Send music shares to friends
✅ View received and sent shares
✅ Feed with friend-to-friend activity
✅ Music search (tracks and artists)
✅ Artist detail pages with top tracks
✅ Preview playback (30s clips)
✅ Mini player and full-screen player
✅ Cross-platform track matching (ISRC)

## Planned Features (See FEATURE_ROADMAP.md)

🚧 Live viral dashboard (track share propagation)
🚧 Timestamped reactions (emoji at specific moments)
🚧 Share impact analytics and feedback loops
🚧 Leaderboards and gamification
🚧 Achievements and badges
🚧 Weekly challenges
🚧 Listening party mode (synchronized playback)
🚧 Taste compatibility scores
🚧 Discovery credits ("You made them discover")

## Known Limitations

- **Preview URLs:** Not all tracks have 30s previews (fallback to Apple Music implemented)
- **Apple Music Search:** Limited to single track search (no bulk artist search yet)
- **Platform Tokens:** Refresh logic exists but not fully tested for expired tokens
- **Viral Tracking:** Not yet implemented (shares don't track parent-child relationships)
- **Real-time:** Supabase Realtime subscriptions not yet implemented

## Development Conventions

### Code Style
- Swift: Follow Swift API Design Guidelines
- SwiftUI: Use declarative views, avoid imperative logic
- Services: Singleton pattern (`shared` instance)
- Async/await: Prefer over completion handlers
- Error handling: Use `throws` and `try/catch`

### Naming
- Models: PascalCase (User, Share, Friendship)
- Services: PascalCase + "Service" suffix
- ViewModels: PascalCase + "State" suffix
- Views: PascalCase + "View" suffix
- Functions: camelCase, verb-first (getUserData, sendShare)

### Git Workflow
- Main branch: `phase/1-social-mvp`
- Commit messages: Clear and descriptive, no emojis
- Format: `feat: Add feature description` or `fix: Bug description`
- **Commit early and often:** Make small, focused commits rather than large batches
- Push regularly to keep remote up to date

### Database Conventions
- Table names: plural, lowercase (users, shares, friendships)
- Column names: snake_case
- UUIDs: Use uuid_generate_v4() for primary keys
- Timestamps: Use timestamptz with timezone
- RLS: Always enabled, test policies thoroughly

## Testing & Debugging

### Test User
- **Auth User ID:** `45DB2427-9B99-49BF-A334-895EC91B038C`
- **Email:** (varies based on platform)
- **Dummy Friends:** Emma, Marcus, Sofia, Tyler, Maya, Alex, Jordan, Taylor
- **Pending Requests:** Ryan, Lisa

### Common Issues

**"No friends found"**
- Check RLS policies are applied (`006_force_fix_rls.sql`)
- Verify friendships exist in database for auth_user_id
- Confirm user has correct auth_user_id in users table

**"Preview URL not available"**
- Normal - many tracks lack previews
- App automatically falls back to Apple Music catalog search
- Check console logs for fallback attempts

**"Policy already exists" error**
- Use idempotent SQL with `DROP POLICY IF EXISTS`
- Run `006_force_fix_rls.sql` for clean slate

**Build errors in Xcode**
- Clean build folder (Cmd+Shift+K)
- Update package dependencies
- Check Swift version compatibility

## Resources

- **Spotify API Docs:** https://developer.spotify.com/documentation/web-api
- **Apple Music API:** https://developer.apple.com/documentation/applemusicapi
- **MusicKit:** https://developer.apple.com/documentation/musickit
- **Supabase Docs:** https://supabase.com/docs
- **SwiftUI:** https://developer.apple.com/documentation/swiftui

## AI Assistant Guidelines

### When to Proactively Offer Git Commits/Pushes

The AI assistant should proactively suggest committing and pushing changes at these moments:

#### Automatic Triggers
1. **After completing a TodoWrite task** - When marking a task as `completed`, immediately offer to commit that work
2. **After 3+ file edits** - When multiple files have been created/modified, suggest a checkpoint commit
3. **After completing a feature** - When a discrete feature or functionality is working
4. **After fixing bugs** - When one or more bugs have been resolved
5. **After creating documentation** - When significant docs are added/updated
6. **At natural stopping points** - End of a logical work session or before switching contexts

#### Commit Message Format
- Use conventional commit format: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Keep messages clear and descriptive
- No emojis in commit messages
- Example: `feat: Add viral dashboard visualization component`

#### Standard Workflow
When offering to commit:
1. Run `git status` to show what's changed
2. Ask user to confirm commit
3. Draft appropriate commit message
4. Stage files with `git add`
5. Commit with message
6. Push to remote branch
7. Confirm success with `git status`

#### Integration with TodoWrite
- When marking a todo as `completed`, the assistant should:
  1. Check if there are uncommitted changes (`git status`)
  2. If changes exist, offer: "I've completed [task]. Should I commit and push this progress?"
  3. Wait for user confirmation
  4. Execute commit workflow if approved

### Example Interaction Pattern

```
Assistant: I've completed fixing the compilation errors. All warnings are now resolved.
[Marks todo as completed]

I've modified 6 files:
- AuthService_v2.swift
- PlaybackService.swift
- SearchService.swift
- UserService.swift
- GeometricLogoView.swift
- ArtistDetailView.swift

Should I commit and push this progress?

User: yes

Assistant: [Runs git status, stages files, commits with "fix: Resolve Xcode compilation errors and warnings", pushes to remote]

Commit created and pushed successfully\!
```

---

## Contact & Support

For questions or issues with this project, refer to:
- Feature roadmap: `docs/FEATURE_ROADMAP.md`
- Auth implementation: `AUTHSERVICE_V2_IMPLEMENTATION.md`
- Database schema: `packages/database/migrations/`
- Migration guide: `SUPABASE_AUTH_MIGRATION_GUIDE.md`

---

**Last Updated:** November 1, 2025
**Current Phase:** Phase 1 - Social MVP (Complete)
**Next Phase:** Viral Dashboard & Engagement Mechanics
