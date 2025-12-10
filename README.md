# Phlock - CS1060 Fall 2025 Project Submission

A social music app where users share one song per day with people whose taste they trust.

Each user curates a 5-person "phlock" - friends, family, influencers, or artists - whose daily picks become their personalized playlist.

## Project Overview

Phlock reimagines music discovery by limiting users to **one song per day**. Instead of algorithmic recommendations, your daily playlist comes from 5 people you've chosen to trust with your listening time.

### Core Mechanics
- **Daily curation**: Pick one song each day, building streaks
- **5-person phlock**: Your playlist = your 5 curators' daily picks
- **Social currency**: Your "phlock count" shows how many people include you in their phlock
- **Midnight swaps**: Change your phlock anytime; swaps take effect at midnight

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS App | SwiftUI (iOS 16+) |
| Backend | Supabase (PostgreSQL + Edge Functions) |
| Auth | Apple Sign-In, Google Sign-In |
| Music | Spotify OAuth, Apple Music OAuth |
| Audio | AVFoundation for preview playback |

## Repository Structure

```
apps/ios/phlock/phlock/    # SwiftUI iOS application
├── Models/                # Data models (User, Share, Notification)
├── Services/              # Backend integration (Auth, Share, User, Playback)
├── ViewModels/            # State management
├── Views/                 # SwiftUI views
│   ├── Auth/              # Onboarding and authentication
│   ├── Main/              # Core app tabs (Phlock, Discover, Profile)
│   └── Components/        # Reusable UI components
└── Utilities/             # Helpers and extensions

supabase/
├── migrations/            # Database schema migrations
└── functions/             # Edge functions (validate-track, search)

tests/                     # Jest test suite
```

## Key Features Implemented

### Authentication & Onboarding
- Apple Sign-In and Google Sign-In
- Name and username selection
- Contacts permission and friend discovery
- Friend invites via SMS
- Push notification permission
- Music platform connection (Spotify/Apple Music)

### Daily Song Selection
- Platform-aware search (Spotify/Apple Music)
- Track validation via edge function
- Preview URL fetching with Apple Music fallback
- 280-character notes
- Streak tracking

### Phlock Feed
- TikTok/Reels-style vertical scroll interface
- Full-screen player with swipe gestures
- Queue-based playback with autoplay
- Mini player across all views

### Social Features
- Friend requests and acceptance
- Phlock member management (positions 1-5)
- Daily nudge notifications
- Social engagement (likes, comments)
- Push notifications with deep linking

### Sharing
- Share to Messages, WhatsApp, Instagram, Instagram Stories
- Copy shareable links
- Share card generation

## Running the Project

### Prerequisites
- Xcode 15+
- iOS 16+ simulator or device
- Node.js 18+

### iOS App
```bash
open apps/ios/phlock/phlock.xcodeproj
# Build and run (Cmd+R)
```

### Test Suite
```bash
npm install
npm test
```

See [TEST_SUITE.md](TEST_SUITE.md) for detailed test documentation.

---

**Course**: CS1060 Fall 2025
**Submitted**: December 2025
