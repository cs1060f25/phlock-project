# Phlock

> A social layer for music discovery that makes peer recommendations measurable and rewarding

Phlock sits on top of Spotify and Apple Music to make music sharing frictionless, recognize fan influence, and give artists new ways to activate and reward their communities.

## 📁 Repository Structure

This is a monorepo containing all Phlock applications and shared packages:

```
phlock/
├── apps/
│   ├── mobile/           # React Native + Expo mobile app (iOS & Android)
│   └── artist-dashboard/ # Next.js web app for artists (Phase 5+)
├── packages/
│   ├── api/              # Backend API & serverless functions
│   ├── database/         # Supabase schemas & migrations
│   ├── shared-types/     # Shared TypeScript types
│   └── utils/            # Shared utilities
├── docs/
│   ├── PHLOCK_ROADMAP.md        # Comprehensive 7-phase roadmap
│   └── BRANCHING_STRATEGY.md    # Git workflow & branch structure
└── package.json          # Workspace root configuration
```

## 🚀 Quick Start

### Prerequisites

- Node.js ≥ 18.0.0
- npm ≥ 8.0.0
- For mobile development: Expo CLI

### Installation

```bash
# Install all dependencies (root + all workspaces)
npm install

# Run mobile app
npm run dev:mobile

# Run artist dashboard (when available)
npm run dev:dashboard
```

### Mobile App Development

```bash
cd apps/mobile

# Start Expo development server
npm start

# Run on iOS simulator
npm run ios

# Run on Android emulator
npm run android
```

## 🎯 Phase-Based Development Roadmap

Phlock is being built in 7 phases over 18-24 months. See [`docs/PHLOCK_ROADMAP.md`](docs/PHLOCK_ROADMAP.md) for the complete roadmap.

### Current Phase: Phase 1 - Social MVP (Months 1-3)

**Goal:** Transform musiclinkr from a utility into a social sharing platform

**Key Features:**
- User authentication & social graph
- Transform link conversion into peer-to-peer sharing
- The Crate - social discovery timeline
- Daily send limits
- In-app preview playback

**Branch:** `phase/1-social-mvp`

## 🌳 Branching Strategy

We use **phase-based feature branching** aligned with our roadmap. See [`docs/BRANCHING_STRATEGY.md`](docs/BRANCHING_STRATEGY.md) for complete details.

### Key Branches

- **`main`** - Production releases
- **`develop`** - Integration branch for current phase
- **`phase/N-name`** - Long-running branches for each development phase
- **`feature/N-name`** - Short-lived feature branches
- **`release/vN-name`** - Release preparation branches

### Example Workflow

```bash
# Start working on a Phase 1 feature
git checkout phase/1-social-mvp
git checkout -b feature/1-firebase-auth

# ... make changes ...
git commit -m "Add Firebase authentication"
git push origin feature/1-firebase-auth

# Create PR: feature/1-firebase-auth → phase/1-social-mvp
```

## 🏗️ Architecture

### Mobile App (`apps/mobile/`)

- **Framework:** React Native + Expo
- **Foundation:** musiclinkr-mobile (cross-platform music link converter)
- **APIs:** Spotify, Apple Music, YouTube, SoundCloud, Tidal, Amazon Music
- **Key Feature:** Universal Track ID (UTID) system for cross-platform mapping

### Artist Dashboard (`apps/artist-dashboard/`)

- **Framework:** Next.js (Phase 5+)
- **Purpose:** Analytics, fan engagement, influence scoring for artists

### Shared Packages

- **`packages/api/`** - Backend functions (authentication, shares, phlocks, influence scoring)
- **`packages/database/`** - Supabase schemas (users, friendships, shares, engagements)
- **`packages/shared-types/`** - TypeScript interfaces shared across apps
- **`packages/utils/`** - Shared utility functions

## 📊 Development Phases

| Phase | Timeline | Status | Key Features |
|-------|----------|--------|--------------|
| **Phase 1** | Months 1-3 | 🚧 In Progress | Social MVP: Auth, Friends, Sharing, Crate |
| **Phase 2** | Months 3-5 | ⏳ Planned | Feedback Loops: Notifications, Metrics |
| **Phase 3** | Months 5-7 | ⏳ Planned | Phlocks Visualization |
| **Phase 4** | Months 7-9 | ⏳ Planned | Proof-of-Influence System |
| **Phase 5** | Months 9-12 | ⏳ Planned | Artist Dashboard |
| **Phase 6** | Months 12-18 | ⏳ Planned | Growth & Viral Mechanics |
| **Phase 7** | Months 18-24 | ⏳ Planned | Monetization & Scale |

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests for specific app
npm test --workspace=apps/mobile
```

## 🚢 Deployment

- **Mobile:** Expo + EAS Build → App Store & Google Play
- **Artist Dashboard:** Vercel
- **API:** Supabase Edge Functions

## 📚 Documentation

- [Phlock Roadmap](docs/PHLOCK_ROADMAP.md) - Comprehensive 7-phase development plan
- [Branching Strategy](docs/BRANCHING_STRATEGY.md) - Git workflow & conventions
- [Mobile App README](apps/mobile/README.md) - React Native app documentation

## 🤝 Contributing

This is a private development repository. Branching strategy:

1. Create feature branch from relevant phase branch
2. Make changes and commit
3. Push and create pull request to phase branch
4. After review, merge to phase branch
5. When phase complete, create release branch → merge to main

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- **GitHub:** https://github.com/woon-1/phlock
- **Roadmap:** [docs/PHLOCK_ROADMAP.md](docs/PHLOCK_ROADMAP.md)

---

**Current Phase:** Phase 1 - Social MVP
**Active Branch:** `phase/1-social-mvp`
**Last Updated:** October 2025