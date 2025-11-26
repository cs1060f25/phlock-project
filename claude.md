# Phlock - Daily Music Curation Platform

## Project Overview

Phlock is a daily music curation app where each user picks one song per day and listens to a 5-person “phlock” playlist from the friends they choose. The new direction emphasizes:
- Daily picks that refresh at midnight
- Lightweight social currency (how many phlocks you’re in)
- Simple notifications and nudges to keep people picking
- Fast TestFlight readiness on iOS 16+

**Current Branch:** `product/daily-curation` (always shippable)
**Status:** TestFlight-ready build with daily song flows scaffolded; several launch gaps remain (friend discovery, external sharing, push/universal links).

## Tech Stack

### Frontend
- SwiftUI + Swift 5, MVVM-ish view models
- iOS 16.0+ (deployment target lowered; see TESTFLIGHT_CHANGES_SUMMARY.md)
- Music integrations: Spotify Web API, Apple Music (MusicKit)
- Authentication: Supabase OAuth via `AuthServiceV2`

### Backend
- Supabase Postgres + RLS
- Supabase Auth (OAuth providers)
- Supabase Storage for profile photos
- Edge Functions (TypeScript/Deno): track validation (`validate-track`), search helpers, auth exchange (legacy)

### Infrastructure
- Monorepo (Turborepo layout)
- Deployment: Supabase Cloud
- Primary docs: `README.md`, `AUTHSERVICE_V2_IMPLEMENTATION.md`, `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md`, `TESTFLIGHT_*`

## Repository Structure (high level)

```
phlock-dev/
├── apps/ios/phlock/phlock/        # iOS app (models, services, views, viewmodels, components)
├── packages/database/migrations/  # DB migrations (legacy path; new ones also in supabase/migrations)
├── supabase/
│   ├── migrations/                # Latest SQL migrations (notifications, etc.)
│   ├── seed/                      # Seed/demo data (e.g., demo_notifications.sql)
│   └── functions/                 # Edge functions
├── docs/                          # Roadmaps and guides
└── TESTFLIGHT_*                   # Deployment quickstart and summaries
```

## Product Shape (Daily Curation)

- One song per user per day; daily streak tracked.
- A user’s playlist is the 5 people in their phlock (positions 1–5).
- Swaps allowed anytime; take effect at midnight.
- Social currency: phlock count (how many phlocks include you).
- Notifications for nudges, friend accepts, daily picks (backend/UI partially present).

## Implementation Status (high signal)

### Completed / Working
- Auth: Supabase OAuth via `AuthServiceV2`; session handling wired in `AuthenticationState`.
- Daily songs: `ShareService` has daily pick helpers; DiscoverView modifications partly in place.
- Notifications UI: `NotificationsView` renders fetched/fallback notifications.
- Notifications backend: `NotificationService` with Supabase fetch/insert and daily-nudge upsert.
- Notifications schema: `supabase/migrations/20251201090000_create_notifications_table.sql` adds table, RLS, indexes.
- iOS 16 compatibility fixes; TestFlight manifest (`PrivacyInfo.xcprivacy`), privacy policy template, deployment guides.

### In Progress / Partial
- Friend discovery: still manual search only (`FriendsView`); no contacts/invite links yet.
- External sharing: QuickSendBar stubs for iMessage/Instagram; WhatsApp is plain text.
- Push + deep links: no APNs setup, no Associated Domains/Universal Links; `phlockApp.swift` only handles OAuth callbacks.
- Notification types mismatch: DB supports `friend_request_accepted`, `daily_nudge`; app expects more types (friend_request_received, friend_joined, friend_picked_song, reaction_received, streak_milestone). Needs migration + backend emitters.
- Mark-as-read/delete: UI toggles locally; no backend call yet.
- Secrets: real keys live in `apps/ios/phlock/phlock/Services/Config.swift` (must be moved to build configs for production).

## Key Services (iOS)

- `AuthService_v2.swift` — Supabase OAuth (Spotify/Apple), session management, profile linking.
- `ShareService.swift` — Sharing and daily pick selection; uses `validate-track` edge function.
- `UserService.swift` — Friends/phlock management; caches unbounded (needs eviction). Creates notifications on accept.
- `NotificationService.swift` — Fetch/insert notifications; aggregates daily nudges; fallback demo data if table missing.
- `PlaybackService.swift` — Preview playback with fallback.
- `SearchService.swift` — Platform-aware search using user’s linked platform.

## Core Models / Schema Notes

- `User`: extended with phlock fields (`phlock_count`, `daily_song_streak`, `last_daily_song_date`), optional platform ids.
- `Share`: supports `is_daily_song`, `selected_date`, `preview_url`.
- `Friendship`: positions + `is_phlock_member`, `last_swapped_at`.
- `notifications` table: currently limited to two types; add types to match `NotificationType` enum in `Models/NotificationItem.swift`.

## UX Surface (current tabs)

- Discover: search + daily song picker (needs refinement to force single daily pick).
- Inbox / Daily Playlist: receive shares and daily picks (UI exists; ensure daily grouping).
- Friends/My Phlock: manual search, friend list, phlock management UI in progress.
- Notifications: list view with sections, fallback demo data.
- Profile: shows version/build; general profile settings.

## TestFlight Readiness (snapshot)

- Build verified on iOS 16 simulator; deployment target lowered to 16.0.
- Privacy manifest added; privacy policy template exists (must be hosted before submission).
- Quickstart + deployment guides: `TESTFLIGHT_QUICKSTART.md`, `TESTFLIGHT_DEPLOYMENT_GUIDE.md`, `TESTFLIGHT_CHANGES_SUMMARY.md`.
- Required manual steps: host privacy policy URL, create App Store Connect app, screenshots, archive/upload, configure testers.

## Known Gaps Before Production

1) Friend discovery: contact sync, invite links/QR, suggestions.  
2) External sharing: implement iMessage/Instagram shares with universal links; enrich WhatsApp.  
3) Push + deep links: APNs tokens, edge function to send pushes, Associated Domains, URL routing for invites/tracks.  
4) Notifications schema mismatch: migrate DB to include all `NotificationType` values; emit on friend requests, daily picks, reactions.  
5) Secrets/config: move Supabase/Spotify/Apple keys out of source; use per-env config.  
6) Error handling + caching: add eviction to `UserService` caches; improve user-facing errors/retries.  
7) Daily flows polish: enforce single daily pick, better empty states, badge/read handling for notifications.

## Environment & Config

- iOS target: 16.0+ (see `TESTFLIGHT_CHANGES_SUMMARY.md`).
- Config lives in `apps/ios/phlock/phlock/Services/Config.swift`; replace with build-configured secrets before production.
- Supabase migrations: run `supabase/migrations/*` then seeds (e.g., `supabase/seed/demo_notifications.sql`).

## Development Notes

- Main branch for this work: `product/daily-curation`.
- Auth callback handled in `phlockApp.swift` via `onOpenURL`; add universal link/deep link routing when ready.
- Fonts: Lora (navigation/title styling). Deployment target fixes applied for `.onChange` syntax and empty states.

## Resources

- Auth details: `AUTHSERVICE_V2_IMPLEMENTATION.md`
- Critical gaps & plan: `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md`
- TestFlight steps: `TESTFLIGHT_QUICKSTART.md`, `TESTFLIGHT_DEPLOYMENT_GUIDE.md`, `TESTFLIGHT_CHANGES_SUMMARY.md`
- Notifications schema: `supabase/migrations/20251201090000_create_notifications_table.sql`
- Demo data: `supabase/seed/demo_notifications.sql`

---

**Last Updated:** December 12, 2025  
**Current Phase:** Daily Curation TestFlight prep  
**Next Focus:** Friend discovery + sharing + push/universal links to unblock production
