# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

### iOS App
```bash
# Open project in Xcode
open apps/ios/phlock/phlock.xcodeproj

# Build from command line (debug)
xcodebuild -project apps/ios/phlock/phlock.xcodeproj -scheme phlock -sdk iphonesimulator -configuration Debug build

# Archive for TestFlight
xcodebuild archive -scheme phlock -archivePath build/phlock.xcarchive
xcodebuild -exportArchive -archivePath build/phlock.xcarchive -exportPath build/ipa
```

### Supabase Backend
```bash
# Apply database migrations
supabase db push

# Run seed data
supabase db execute -f supabase/seed/demo_notifications.sql

# Deploy edge functions
supabase functions deploy validate-track
supabase functions deploy <function-name>

# Check status
supabase status
```

### Monorepo (Turborepo)
```bash
npm run build    # Build all packages
npm run test     # Run all tests
npm run lint     # Lint all packages
```

## Architecture Overview

### iOS App (`apps/ios/phlock/phlock/`)

**MVVM-ish pattern** with SwiftUI:
- `Services/` — Backend integration and business logic
- `ViewModels/` — State management for views
- `Views/` — SwiftUI view components
- `Models/` — Data models and Codable structs
- `Extensions/` — Swift type extensions
- `Helpers/` & `Utilities/` — Shared utilities

**Key Services:**
| Service | Purpose |
|---------|---------|
| `AuthService_v2.swift` | Supabase OAuth (Spotify/Apple), session management |
| `ShareService.swift` | Daily song picks, sharing via `validate-track` edge function |
| `UserService.swift` | Friends/phlock management, caching |
| `PlaybackService.swift` | Audio preview playback |
| `SearchService.swift` | Platform-aware search (Spotify/Apple Music) |
| `NotificationService.swift` | Notifications with fallback demo data |
| `PhlockService.swift` | Phlock membership and swaps |

**Auth Flow:** `phlockApp.swift` handles OAuth callbacks via `onOpenURL`. Session state managed by `AuthenticationState` environment object.

### Supabase Backend

**Edge Functions (`supabase/functions/`):**
- `validate-track/` — Validates track data, fetches preview URLs
- `search-spotify-tracks/` — Spotify search proxy
- `get-spotify-track/` — Single track lookup
- `process-scheduled-swaps/` — Midnight phlock swap processor

**Database Migrations (`supabase/migrations/`):** Applied via `supabase db push`. Key tables:
- `users` — Extended with `phlock_count`, `daily_song_streak`, `last_daily_song_date`
- `shares` — Supports `is_daily_song`, `selected_date`, `preview_url`
- `friendships` — Positions 1-5, `is_phlock_member`, `last_swapped_at`
- `notifications` — Types: `friend_request_accepted`, `daily_nudge` (more types needed)

### Data Flow

1. **Daily Song Selection:** User searches → picks song → `ShareService` calls `validate-track` → stores in `shares` with `is_daily_song=true`
2. **Phlock Playlist:** User's 5 phlock members' daily songs fetched via `PhlockService` → displayed in inbox
3. **Notifications:** `NotificationService` fetches from Supabase, falls back to demo data if table missing

## Product Context

**Daily Curation Model:**
- One song per user per day (tracked by streak)
- Each user has a 5-person "phlock" (positions 1-5)
- Your daily playlist = your 5 phlock members' picks
- Phlock swaps: If the member has already picked for the day, the swap takes effect at midnight. If they haven't picked yet, the swap is immediate.
- Social currency = how many other phlocks include you

## Configuration

**Secrets Location:** `apps/ios/phlock/phlock/Services/Config.swift`
Contains Supabase URL/keys, Spotify client ID, redirect URIs. Must move to build configs before production.

**iOS Target:** 16.0+ (deployment target lowered for broader compatibility)

**Fonts:** Lora for headers and hero text, DM Sans for body text

## Current Branch

`product/daily-curation` — Always shippable, TestFlight-ready

## Key Documentation

- `TESTFLIGHT_QUICKSTART.md` — Step-by-step TestFlight deployment
- `TESTFLIGHT_DEPLOYMENT_GUIDE.md` — Complete deployment walkthrough
- `AUTHSERVICE_V2_IMPLEMENTATION.md` — OAuth integration details
- `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md` — Gaps and priorities

## Known Gaps (Pre-Production)

1. **Auth strategy undecided:** Need to determine whether to use phone number, email, Apple Sign-In, or Google Sign-In for primary authentication (currently using Spotify/Apple Music OAuth)
2. **Username creation flow:** Need to design and implement username selection/creation during onboarding
3. Friend discovery: No contacts sync or invite links
4. External sharing: iMessage/Instagram stubs only
5. Push notifications: No APNs setup
6. Notification types: DB has 2 types, app expects 6+
7. Secrets: Still in source code
8. Caching: No eviction policy in UserService
