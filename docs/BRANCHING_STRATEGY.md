# Phlock Branching Strategy

This document outlines the git branching strategy for the Phlock monorepo, aligned with our 7-phase development roadmap.

## Strategy Overview

We use **Phase-Based Feature Branching** - a variant of trunk-based development optimized for our phased rollout strategy.

## Branch Types

### 1. `main` - Production Branch

- **Purpose:** Production-ready code, always deployable
- **Protection:** Requires PR + passing CI tests
- **Merges from:** `release/*` branches only
- **Deploy target:** Production (App Store, Google Play, production web)
- **Tagging:** All releases tagged with version numbers

### 2. `develop` - Integration Branch

- **Purpose:** Current phase integration and testing
- **Protection:** Requires passing CI tests
- **Merges from:** `phase/*` branches
- **Merges to:** `release/*` branches when phase complete
- **Deploy target:** Staging/TestFlight environment

### 3. `phase/*` - Phase Container Branches

Long-running branches (1-3 months) for each development phase.

**Naming Convention:** `phase/N-phase-name`

**Examples:**
- `phase/1-social-mvp`
- `phase/2-feedback-loops`
- `phase/3-phlocks-visualization`
- `phase/4-proof-of-influence`
- `phase/5-artist-dashboard`
- `phase/6-growth-mechanics`
- `phase/7-monetization`

**Lifecycle:**
1. Created from `develop` at phase start
2. Collects all feature branches for that phase
3. Merged to `develop` when features complete
4. Merged to `release/*` when phase ready for launch
5. Kept for reference, potentially deleted after release

### 4. `feature/*` - Feature Branches

Short-lived branches (1-2 weeks) for individual features.

**Naming Convention:** `feature/{phase-number}-{feature-name}`

**Examples:**
- `feature/1-firebase-auth`
- `feature/1-send-flow-ui`
- `feature/2-notification-system`
- `feature/3-phlock-visualization`

**Lifecycle:**
1. Created from relevant `phase/*` branch
2. Development happens here
3. PR created to merge back to `phase/*` branch
4. Deleted after merge

**Rules:**
- Keep focused on single feature
- Rebase frequently from parent phase branch
- Must pass CI before merging
- Require 1 review (if team > 1 person)

### 5. `release/*` - Release Preparation Branches

Created when a phase is ready to ship.

**Naming Convention:** `release/v{version}-{phase-name}`

**Examples:**
- `release/v0.1-friends-family` (Phase 1 launch)
- `release/v0.2-industry-insiders` (Phase 2 launch)
- `release/v0.3-phlocks-launch` (Phase 3 launch)

**Lifecycle:**
1. Created from `phase/*` branch when ready
2. Bug fixes only (no new features)
3. Tested thoroughly
4. Merged to both `main` AND `develop`
5. Tagged in `main` with version number
6. Deleted after successful deployment

### 6. `hotfix/*` - Emergency Production Fixes

For critical bugs in production.

**Naming Convention:** `hotfix/{description}`

**Examples:**
- `hotfix/auth-crash-ios`
- `hotfix/data-loss-bug`

**Lifecycle:**
1. Created from `main`
2. Fix applied
3. Merged to both `main` AND `develop`
4. Tagged immediately
5. Deleted after merge

## Workflow Examples

### Daily Feature Development

```bash
# Check out phase branch
git checkout phase/1-social-mvp
git pull origin phase/1-social-mvp

# Create feature branch
git checkout -b feature/1-firebase-auth

# ... make changes ...
git add .
git commit -m "Add Firebase authentication with phone/email"

# Push and create PR
git push origin feature/1-firebase-auth

# On GitHub: Create PR from feature/1-firebase-auth → phase/1-social-mvp
# After review and approval, merge via GitHub UI
# Then delete feature branch
```

### Completing a Phase

```bash
# Phase 1 features all merged to phase/1-social-mvp
# Ready to prepare for Friends & Family launch

# Create release branch
git checkout phase/1-social-mvp
git checkout -b release/v0.1-friends-family

# Bug fixes and polish
git commit -m "Fix: Notification delivery on iOS"
git commit -m "Polish: Improve Crate scroll performance"

# When ready, merge to main
git checkout main
git merge release/v0.1-friends-family
git tag v0.1.0
git push origin main --tags

# Also merge back to develop
git checkout develop
git merge release/v0.1-friends-family
git push origin develop

# Delete release branch
git branch -d release/v0.1-friends-family
```

### Working on Multiple Phases in Parallel

```bash
# While Phase 1 is in beta testing...
# You can start Phase 2 features

# Ensure develop is up to date
git checkout develop
git pull origin develop

# Create Phase 2 branch
git checkout -b phase/2-feedback-loops

# Start Phase 2 feature
git checkout -b feature/2-engagement-signals

# ... work on Phase 2 ...
# Meanwhile Phase 1 can still receive bug fixes
```

## Phase-to-Branch Mapping

| Phase | Branch Name | Features | Timeline |
|-------|-------------|----------|----------|
| **Phase 1** | `phase/1-social-mvp` | Auth, Friends, Send, Crate, Limits | Months 1-3 |
| **Phase 2** | `phase/2-feedback-loops` | Notifications, Metrics, Library Detection | Months 3-5 |
| **Phase 3** | `phase/3-phlocks` | Visualization, Sharing, Gallery | Months 5-7 |
| **Phase 4** | `phase/4-proof-of-influence` | Scoring Algorithm, Dashboards | Months 7-9 |
| **Phase 5** | `phase/5-artist-dashboard` | Artist Portal, Tools, Pricing | Months 9-12 |
| **Phase 6** | `phase/6-growth` | Viral Mechanics, Gamification | Months 12-18 |
| **Phase 7** | `phase/7-monetization` | Subscriptions, Fees, A&R | Months 18-24 |

## Commit Message Conventions

### Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

### Examples

```
feat: Add Firebase authentication with email/phone

Implemented Firebase Auth SDK integration with support for:
- Email/password authentication
- Phone number authentication
- Social auth providers (Google, Apple)

Closes #12
```

```
fix: Prevent crash when opening empty Crate

Added null check before rendering Crate items to handle
edge case when user has no received shares yet.

Fixes #45
```

## Branch Protection Rules

### `main` Branch

- ✅ Require pull request reviews (1 approval minimum)
- ✅ Require status checks to pass before merging
- ✅ Do not allow bypassing the above settings
- ✅ Do not allow force pushes
- ✅ Do not allow deletions

### `develop` Branch

- ✅ Require status checks to pass before merging
- ⚠️ Allow force pushes (for rebasing, admin only)
- ✅ Do not allow deletions

### `phase/*` Branches

- ✅ Require status checks to pass
- ⚠️ Minimal protection (frequent rebasing expected)

## Continuous Integration

### On Pull Requests

- Run linting (ESLint, Prettier)
- Run all tests
- Build mobile app (iOS + Android)
- Build artist dashboard
- Check for TypeScript errors

### On `develop` Branch

- All PR checks plus:
- Deploy to staging environment
- Run E2E tests
- Generate preview build

### On `main` Branch

- All develop checks plus:
- Deploy to production
- Submit to App Store / Google Play
- Create GitHub release
- Notify team

## FAQ

**Q: Can I work on Phase 2 features while Phase 1 is still in development?**

A: Yes! Create the `phase/2-feedback-loops` branch from `develop` and start feature branches from there. The phase branches are independent.

**Q: What if I need to make a quick fix to the current phase branch?**

A: For small fixes (< 10 lines), you can commit directly to the phase branch. For anything larger, create a feature branch.

**Q: How do I handle dependencies between features in different phases?**

A: If Feature B (Phase 2) depends on Feature A (Phase 1), merge Feature A to `develop` first, then rebase `phase/2-feedback-loops` from `develop`.

**Q: Should I delete phase branches after release?**

A: You can, but it's recommended to keep them for 30 days post-release for reference. Archive them with a tag if needed.

## Resources

- [Phlock Roadmap](PHLOCK_ROADMAP.md)
- [Root README](../README.md)
- [GitHub Flow Documentation](https://guides.github.com/introduction/flow/)

---

**Last Updated:** October 2025
