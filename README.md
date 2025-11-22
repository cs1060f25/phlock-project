# Phlock - Daily Music Curation Platform

> A social music discovery app where users curate daily playlists for each other

Phlock transforms music discovery through daily curation. Each user selects one song per day, and their "phlock" (5 curators they follow) provides their daily personalized playlist. Social currency is built through being included in others' phlocks - the more phlocks you're in, the more influential you become.

## 🎵 Core Concept

- **Daily Song Selection**: Pick one song per day to share with your followers
- **Your Phlock**: Choose 5 people whose daily songs become your playlist
- **Social Currency**: Phlock count (how many people include you) = influence
- **Swap Mechanism**: Adjust your phlock anytime - changes take effect at midnight
- **Streaks**: Build momentum by selecting songs daily

## 📁 Repository Structure

This is a monorepo containing the Phlock iOS app and backend infrastructure:

```
phlock-dev/
├── apps/
│   ├── ios/phlock/              # Native SwiftUI iOS app
│   └── mobile-rn-archive/       # Archived React Native implementation
├── packages/
│   └── database/
│       └── migrations/          # Supabase database migrations
├── supabase/
│   ├── functions/               # Edge Functions (auth, search)
│   └── seed/                    # Test data
├── docs/
│   └── FEATURE_ROADMAP.md       # Future features
├── CLAUDE.md                    # Complete project documentation
└── README.md                    # This file
```

## 🚀 Quick Start

### Prerequisites

- **iOS Development:**
  - Xcode 15+
  - iOS 15+ deployment target
- **Backend:**
  - Supabase project
  - Spotify Developer account (for OAuth)
  - Apple Developer account (for Apple Music)

### Running the iOS App

```bash
# Open Xcode project
open apps/ios/phlock/phlock.xcodeproj

# Or use command line
cd apps/ios/phlock
xcodebuild -scheme phlock -sdk iphonesimulator
```

### Database Setup

```bash
# Run migrations
supabase db push

# Or manually run each migration
psql $DATABASE_URL < packages/database/migrations/001_initial_schema.sql
# ... continue with subsequent migrations
```

## 🌳 Branch Structure

We use **product-based branching** to explore different product directions:

### Active Branches

- **`main`** - Stable release branch
- **`develop`** - Integration branch
- **`product/viral-sharing`** - Original viral music sharing concept (complete)
- **`product/daily-curation`** - **CURRENT** - Daily playlist curation model

### Tags

- `v1.0-viral-sharing` - Complete viral sharing implementation
- `archive/daily-curation-ground-up` - Reference schema for ground-up rebuild

## 🏗️ Current Architecture (Daily Curation Branch)

### Database Schema

**Core Tables:**
- `users` - User profiles with Spotify/Apple Music OAuth
  - Extended fields: `username`, `phlock_count`, `daily_song_streak`, `last_daily_song_date`
- `shares` - Music shares between users
  - Extended fields: `is_daily_song`, `selected_date`, `preview_url`
- `friendships` - Social connections
  - Extended fields: `position`, `is_phlock_member`, `last_swapped_at`
- `swap_history` - Track daily phlock member swaps
- `platform_tokens` - Encrypted OAuth tokens

**Key Constraints:**
- One song per user per day
- Max 5 phlock members (free tier)
- Unlimited swaps per day (take effect at midnight)
- Streak tracking with auto-reset
- Daily playlist generation at midnight user's timezone

### iOS App Structure

```
phlock/
├── Models/
│   ├── User.swift              # Extended with phlock fields
│   ├── Share.swift             # Extended with daily song fields
│   ├── Friendship.swift
│   └── MusicItem.swift
├── Services/
│   ├── AuthService_v2.swift    # OAuth with Spotify/Apple Music
│   ├── ShareService.swift      # Music sharing (will add daily song methods)
│   ├── UserService.swift       # Friend/phlock management
│   ├── SpotifyService.swift    # Spotify API integration
│   └── AppleMusicService.swift # Apple Music API integration
├── Views/
│   ├── Auth/                   # Authentication flow
│   ├── Main/
│   │   ├── DiscoverView.swift  # Search + daily song selection
│   │   ├── FriendsView.swift   # Will become "My Phlock"
│   │   ├── InboxView.swift     # Will become "Daily Playlist"
│   │   ├── FeedView.swift      # Activity feed
│   │   └── ProfileView.swift   # User profiles
│   └── Components/             # Reusable UI components
└── ViewModels/                 # State management
```

## 🎯 Implementation Status (product/daily-curation)

### ✅ Completed

- [x] Branch restructuring and cleanup
- [x] Incremental database migration (non-breaking)
- [x] Extended Swift models (Share, User)
- [x] Helper methods for daily songs and streaks
- [x] Triggers for auto-maintaining phlock counts and streaks

### 🚧 In Progress

- [ ] ShareService methods for daily song selection
- [ ] DiscoverView modifications (add daily song picker)
- [ ] My Phlock management UI
- [ ] Daily Playlist view
- [ ] Testing migration on Supabase

### 📋 Planned

- [ ] Swap functionality UI
- [ ] Streak display and notifications
- [ ] Premium tier (10 phlock members)
- [ ] Discovery/browse features
- [ ] Artist pitch system (monetization)

## 🔧 Development Workflow

### Current Branch: `product/daily-curation`

This branch uses a **hybrid approach**:
- Starts from working viral-sharing code
- Incrementally adds daily curation features
- Non-breaking changes (both models can coexist)
- Always shippable at every commit

### Typical Development Flow

```bash
# Work on daily curation features
git checkout product/daily-curation

# Make changes incrementally
# ... modify code ...

# Commit frequently
git add -A
git commit -m "feat: Add daily song selection to DiscoverView"
git push origin product/daily-curation

# Test in Xcode - app should always compile and run
```

### Database Migration Strategy

```bash
# Run latest migration
cd supabase
supabase db push

# Or run specific migration
psql $DATABASE_URL < ../packages/database/migrations/007_add_daily_curation_fields.sql

# Verify
supabase db execute "SELECT username, phlock_count, daily_song_streak FROM users LIMIT 5;"
```

## 📊 Key Features

### Daily Song Selection
- Search your music library (Spotify/Apple Music)
- Pick **one song per day** as your contribution
- Add optional 280-character note
- Builds streak counter (gamification)

### Phlock Management
- Choose **5 curators** for your daily playlist
- See each member's today's song
- **Make unlimited swaps** throughout the day - changes take effect at midnight
- Position-based ordering (1-5)

### Daily Playlist
- Auto-generated every day from your 5 phlock members
- Shows which curator contributed each song
- Play directly with preview player
- Track likes/skips for engagement

### Social Currency
- **Phlock count** = how many people include you
- Public/private visibility options
- Leaderboards for top curators
- Discovery based on influence

## 🎨 Design Principles

### Simplicity
- Minimal friction: reuse existing DiscoverView for selection
- One decision per day (which song?)
- Clear constraints (5 members, midnight refresh)

### Engagement
- Daily habit formation
- Streak tracking with visual rewards
- Social proof through phlock counts
- Thoughtful curation (swaps take effect next day)

### Monetization
- **Free tier**: 5 phlock members, basic features
- **Premium ($4.99/mo)**: 10 members, past playlists, analytics
- **Artist tier ($19.99/mo)**: Pitch songs to influencers

## 🧪 Testing

### Manual Testing
```bash
# Open in Xcode
open apps/ios/phlock/phlock.xcodeproj

# Build and run on simulator
# Sign in with Spotify/Apple Music OAuth
# Test daily song selection
# Test phlock management
```

### Database Testing
```bash
# Check migration worked
supabase db execute "SELECT * FROM shares WHERE is_daily_song = true;"

# Verify triggers
supabase db execute "SELECT username, phlock_count FROM users ORDER BY phlock_count DESC LIMIT 10;"
```

## 📚 Documentation

- **[CLAUDE.md](CLAUDE.md)** - Complete technical documentation
- **[FEATURE_ROADMAP.md](docs/FEATURE_ROADMAP.md)** - Future features and monetization
- **Database Migrations** - See `packages/database/migrations/`
- **Seed Data** - See `supabase/seed/`

## 🔐 Environment Setup

### Required Environment Variables

Create `.env.local` in project root:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SPOTIFY_CLIENT_ID=your-spotify-client-id
SPOTIFY_CLIENT_SECRET=your-spotify-client-secret
```

### iOS Config

Update `apps/ios/phlock/phlock/Config.swift`:

```swift
static let supabaseURL = "https://your-project.supabase.co"
static let supabaseAnonKey = "your-anon-key"
static let spotifyClientId = "your-client-id"
static let spotifyRedirectUri = "phlock://spotify-callback"
```

## 📈 Metrics & Success Criteria

### Key Metrics (MVP)
- **Daily Active Users**: % of users selecting a song daily (target: 60%+)
- **Phlock Fill Rate**: Average phlock size (target: 4+ out of 5)
- **Playlist Engagement**: % playing 3+ songs (target: 70%+)
- **Swap Rate**: Swaps per user per week (target: 1-2)
- **7-Day Retention**: (target: 50%+)

### Growth Indicators
- **Average phlock count**: Distribution across users
- **Streak retention**: % maintaining 7+ day streaks
- **Discovery rate**: New songs discovered per user per week

## 🚀 Deployment

### iOS App
```bash
# TestFlight
xcodebuild archive -scheme phlock -archivePath build/phlock.xcarchive
xcodebuild -exportArchive -archivePath build/phlock.xcarchive -exportPath build/ipa

# Upload to App Store Connect
# Deploy to TestFlight beta testers
```

### Database
```bash
# Deploy migrations
supabase db push

# Deploy edge functions
supabase functions deploy exchange-auth-token
supabase functions deploy search-spotify-tracks
```

## 🤝 Contributing

This is a private development repository. For internal development:

1. Check out `product/daily-curation` branch
2. Make incremental, testable changes
3. Commit frequently with clear messages
4. Push to remote regularly
5. Keep app functional at every commit

## 🔗 Links

- **GitHub**: https://github.com/woon-1/phlock
- **Supabase Dashboard**: (your project URL)
- **Spotify Developer Console**: https://developer.spotify.com/dashboard

---

**Current Product Direction**: Daily Curation
**Active Branch**: `product/daily-curation`
**Status**: MVP Development
**Last Updated**: November 22, 2025
