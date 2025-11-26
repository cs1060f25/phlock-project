# Phlock - Daily Music Curation

> Pick one song per day, listen to your 5-person phlock, and build social currency by being in other people’s phlocks.

## What’s in this repo
- `apps/ios/phlock/phlock` — SwiftUI iOS app (iOS 16+, AuthServiceV2, daily curation flows)
- `supabase/migrations` — Current database migrations (notifications table, daily fields)
- `supabase/seed` — Demo data (e.g., `demo_notifications.sql`)
- `supabase/functions` — Edge functions (track validation/search helpers)
- `docs` — Roadmaps/strategy (see “Key docs” below)
- TestFlight guides — `TESTFLIGHT_QUICKSTART.md`, `TESTFLIGHT_DEPLOYMENT_GUIDE.md`, `TESTFLIGHT_CHANGES_SUMMARY.md`
- Project overview — `claude.md`

## Core concept
- One song per user per day; streaks tracked.
- Your playlist is your 5-person phlock (positions 1–5); swaps take effect at midnight.
- Influence = how many phlocks include you.
- Nudges/notifications remind users to pick and react.

## Current status (branch: `product/daily-curation`)
- TestFlight-ready build on iOS 16+ (deployment target lowered; privacy manifest added).
- Notifications UI + service + schema exist; DB supports nudges and friend accepts.
- Daily pick flows are scaffolded; Discover includes picker hooks.
- Critical gaps before production: friend discovery (contacts/invites), external sharing (iMessage/Instagram with universal links), push + deep links, notification type parity, move secrets out of `Config.swift`.

## Quick start
### Prerequisites
- Xcode 15+, iOS 16+ simulator or device
- Supabase project
- Spotify + Apple Music developer accounts

### Run the app
```bash
open apps/ios/phlock/phlock.xcodeproj
# or
cd apps/ios/phlock
xcodebuild -scheme phlock -sdk iphonesimulator
```

### Database
```bash
cd supabase
supabase db push               # apply latest migrations
supabase db execute -f seed/demo_notifications.sql  # optional demo notifications
```

## Branches / tags
- `main` — stable
- `develop` — integration
- `product/daily-curation` — current work (always shippable)
- Tags: `v1.0-viral-sharing`, `archive/daily-curation-ground-up`

## Key docs
- `claude.md` — project snapshot (daily curation direction)
- `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md` — blockers/priorities to production
- `AUTHSERVICE_V2_IMPLEMENTATION.md` — auth details
- `TESTFLIGHT_*` — deployment steps and status
- `PRIVACY_POLICY.md` — host before App Store submission

## Security note
Real Supabase/Spotify/Apple keys are checked into `apps/ios/phlock/phlock/Services/Config.swift` for now. Move these to build configurations/secrets before production.

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
