# Phlock - Daily Music Curation

> Pick one song per day, listen to your 5-person phlock, and build social currency by being in other people's phlocks.

## What's in this repo
- `apps/ios/phlock/phlock` — SwiftUI iOS app (iOS 16+, AuthServiceV2, daily curation flows)
- `supabase/migrations` — Database migrations (notifications, daily fields, RLS policies)
- `supabase/seed` — Demo data (e.g., `demo_notifications.sql`)
- `supabase/functions` — Edge functions (track validation, search helpers)
- `docs` — Roadmaps/strategy
- TestFlight guides — `TESTFLIGHT_QUICKSTART.md`, `TESTFLIGHT_DEPLOYMENT_GUIDE.md`
- Project overview — `CLAUDE.md`

## Core concept
- **One song per user per day**; streaks tracked
- Your playlist is your **5-person phlock** (positions 1–5); swaps take effect at midnight
- **Social currency** = how many phlocks include you
- Nudges/notifications remind users to pick and react

## Current status (branch: `product/daily-curation`)

### Recently Completed
- **Typography overhaul**: DM Sans font family across the entire app (replacing Lora)
- **Enhanced player**: Horizontal swipe gestures for track skipping, improved dismiss gesture
- **Playback queue system**: Full queue support with skip forward/backward, autoplay handling
- **Share system redesign**: New ShareOptionsSheet with Copy Link, Messages, WhatsApp, Instagram, Instagram Stories
- **Daily song gating**: Blur overlay prompts users to pick before viewing phlock
- **Settings view**: Privacy Policy, Terms of Service, Delete Account, Sign Out
- **Nudge tracking**: Per-user nudge state with daily reset
- **Backend RLS**: Phlock members can now upsert daily nudge notifications
- **Performance**: Parallel async loading, phlock member caching

### TestFlight Ready
- iOS 16+ deployment target
- Privacy manifest included
- Build verified on simulator

### Remaining Gaps
- Friend discovery (contacts/invite links)
- External sharing with universal links
- Push notifications + APNs
- Move secrets out of `Config.swift`

## Quick start

### Prerequisites
- Xcode 15+, iOS 16+ simulator or device
- Supabase project
- Spotify + Apple Music developer accounts

### Run the app
```bash
open apps/ios/phlock/phlock.xcodeproj
# Build and run (Cmd+R)
```

### Database
```bash
cd supabase
supabase db push                                    # apply migrations
supabase db execute -f seed/demo_notifications.sql  # optional demo data
```

## Key features

### Daily Song Selection
- Search your music library (Spotify/Apple Music)
- Pick **one song per day** as your contribution
- Add optional 280-character note
- Builds streak counter

### Phlock Management
- Choose **5 curators** for your daily playlist
- See each member's song of the day
- Unlimited swaps—changes take effect at midnight
- Position-based ordering (1–5)

### Playback
- Full-screen player with swipe gestures (dismiss down, skip left/right)
- Queue-based playback with autoplay
- Mini player persistent across views
- Track save/like state

### Sharing
- Share to Messages, WhatsApp, Instagram, Instagram Stories
- Copy shareable Spotify/Apple Music links
- Context-aware share sheet (full player, mini player, overlay)

### Social Currency
- **Phlock count** = how many people include you
- Nudge friends who haven't picked today
- Notifications for friend accepts, nudges

## Branches
- `main` — stable
- `develop` — integration
- `product/daily-curation` — current work (always shippable)

## Key docs
- `CLAUDE.md` — project snapshot
- `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md` — blockers/priorities
- `AUTHSERVICE_V2_IMPLEMENTATION.md` — auth details
- `TESTFLIGHT_*` — deployment guides

## Security note
Supabase/Spotify/Apple keys are in `apps/ios/phlock/phlock/Services/Config.swift`. Move to build configurations before production.

## Environment setup

### iOS Config
Update `apps/ios/phlock/phlock/Config.swift`:
```swift
static let supabaseURL = "https://your-project.supabase.co"
static let supabaseAnonKey = "your-anon-key"
static let spotifyClientId = "your-client-id"
static let spotifyRedirectUri = "phlock://spotify-callback"
```

## Testing

```bash
# Open in Xcode
open apps/ios/phlock/phlock.xcodeproj

# Build and run on simulator
# Sign in with Spotify/Apple Music OAuth
# Test daily song selection and phlock management
```

## Deployment

### iOS (TestFlight)
```bash
xcodebuild archive -scheme phlock -archivePath build/phlock.xcarchive
xcodebuild -exportArchive -archivePath build/phlock.xcarchive -exportPath build/ipa
# Upload to App Store Connect
```

### Database
```bash
supabase db push
supabase functions deploy validate-track
```

## Contributing

1. Check out `product/daily-curation` branch
2. Make incremental, testable changes
3. Commit frequently with clear messages
4. Keep app functional at every commit

---

**Current Branch**: `product/daily-curation`
**Status**: TestFlight Ready
**Last Updated**: November 25, 2025
