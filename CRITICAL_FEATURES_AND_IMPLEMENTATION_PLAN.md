# Phlock - Critical Missing Features & Beta Launch Plan

**Date:** December 12, 2025
**Status:** Daily Curation branch (`product/daily-curation`) - TestFlight-ready build, production gaps remain
**Estimated Beta Launch:** 6-8 weeks (with P0 fixes)

---

## Executive Summary

Analysis of the Phlock iOS app revealed **37 critical gaps** that prevent it from being production-ready. This document outlines all missing features categorized by priority, plus a focused implementation plan to reach beta launch ASAP.

---

## Part 1: Verified Critical Issues

### Issue 1: Friend Discovery is Fundamentally Broken (P0 - BLOCKER)

**Current Implementation:**
- Only manual username search exists in `FriendsView.swift` (lines 158-257)
- Requires exact knowledge of friend's display name
- No other discovery mechanisms

**What's Missing:**
1. Contact sync (iOS Contacts framework)
2. Phone number/email lookup
3. Invite links (shareable URLs)
4. QR code generation/scanning
5. Social media import (Instagram/Facebook)
6. Friend recommendations (mutual friends)

**Why It's a Blocker:**
Users cannot realistically find friends without knowing exact Phlock username. Every successful social app bootstraps via contact sync or invite links.

**Code Location:** `apps/ios/phlock/phlock/Views/Main/FriendsView.swift:158-257`

---

### Issue 2: External Sharing is Completely Broken (P0 - BLOCKER)

**Current Implementation:**
- iMessage: Empty stub function (no implementation)
- Instagram: Empty stub function (no implementation)
- WhatsApp: Only sends plain text, no rich preview

**Code Evidence:**
```swift
// QuickSendBar.swift:738-753

// Line 738-741: iMessage - EMPTY STUB
private func shareViaMessages() {
    print("📱 Sharing via Messages")
    // NO ACTUAL IMPLEMENTATION
}

// Line 750-753: Instagram - EMPTY STUB
private func shareViaInstagram() {
    print("📸 Sharing via Instagram")
    // NO ACTUAL IMPLEMENTATION
}

// Line 743-748: WhatsApp - PARTIALLY WORKS
private func shareViaWhatsApp() {
    if let url = URL(string: "whatsapp://send?text=Check out this track...") {
        UIApplication.shared.open(url)
    }
}
```

**Why It's Broken:**
- iMessage never calls `MFMessageComposeViewController` or `UIActivityViewController`
- Instagram never uses Instagram Stories API or sharing SDK
- WhatsApp only sends plain text, no rich media card or deep link

**Code Location:** `apps/ios/phlock/phlock/Views/Components/QuickSendBar.swift:738-753`

---

### Issue 3: Notifications Stack Misaligned (P0/P1 mix)

**Current Implementation:**
- Notifications table exists with RLS and daily-nudge upsert logic.
- iOS `NotificationsView` and `NotificationService` fetch/render notifications and aggregate nudges.

**What's Missing:**
1. DB only allows `friend_request_accepted` and `daily_nudge`; app expects 5 more types (`friend_request_received`, `friend_joined`, `friend_picked_song`, `reaction_received`, `streak_milestone`).
2. No mark-as-read/delete API; UI toggles only local state.
3. No push delivery: no device token registration, no send-push edge function.

**Why It's a Blocker:**
Notification parity and delivery are required for daily nudges and social loops; without push + proper types, users miss core actions.

**Code/Schema Locations:**  
- Schema: `supabase/migrations/20251201090000_create_notifications_table.sql`  
- RLS fix: `supabase/migrations/20251212120000_fix_notifications_rls_for_nudges.sql`  
- App enum: `apps/ios/phlock/phlock/Models/NotificationItem.swift`  
- Service/UI: `apps/ios/phlock/phlock/Services/NotificationService.swift`, `apps/ios/phlock/phlock/Views/Main/NotificationsView.swift`

## Part 2: All Critical Missing Features

### Priority 0 (P0) - BLOCKERS - Cannot Launch Without These

| # | Feature | Current State | Why Critical | Complexity | Estimate |
|---|---------|---------------|--------------|-----------|----------|
| 1 | Friend Discovery | Only manual username search | Users can't find friends | LARGE | 2-3 weeks |
| 2 | External Sharing (iMessage/IG) | Stubs in QuickSendBar | Can't share off-app | MEDIUM | 1 week |
| 3 | Push + Universal/Deep Links | No APNs/device tokens; no Associated Domains; OAuth-only onOpenURL | No track/invite links, no push delivery | LARGE | 1-1.5 weeks |

**Total P0 Effort:** ~4-5 weeks

---

### Priority 1 (P1) - CRITICAL - Severely Limits Usability

| # | Feature | Current State | Missing Implementation | Complexity | Estimate |
|---|---------|---------------|------------------------|-----------|----------|
| 4 | Notification Type Parity | DB supports only `friend_request_accepted`, `daily_nudge`; app expects 5 more types | Add enum values, emit events, mark-as-read/delete | SMALL | 2-3 days |
| 5 | In-App Notifications | UI exists; backend mark-read missing | Mark read/delete APIs; badge sync | SMALL | 3 days |
| 6 | Friend Invite System | None | Invite attribution, rewards | MEDIUM | 1 week |
| 7 | Delete Account | Sign out only | Account deletion, data export | MEDIUM | 3 days |
| 8 | Change Music Platform | Set once forever | Platform switching, re-link | LARGE | 1 week |
| 9 | Account Recovery | OAuth only | Email verification, password reset | MEDIUM | 5 days |
| 10 | Block/Report Users | None | Block feature, reporting | MEDIUM | 1 week |
| 11 | Privacy Settings | All public | Private accounts, activity hiding | MEDIUM | 1 week |
| 12 | Content Moderation | None | Profanity filter, image moderation | MEDIUM | 5 days |
| 13 | Offline Mode | None | Local cache, queue, retry | LARGE | 2 weeks |
| 14 | Error Handling | Generic alerts | User-friendly messages, retry | MEDIUM | 1 week |
| 15 | Empty States | Basic only | Onboarding tooltips, guidance | SMALL | 3 days |
| 16 | Save to Library | Preview only | Add to Spotify/Apple Music | MEDIUM | 1 week |
| 17 | Full Track Playback | 30s previews | Spotify SDK, Apple Music auth | LARGE | 2-3 weeks |
| 18 | Token Refresh | Untested | Auto-refresh, background refresh | MEDIUM | 5 days |
| 19 | Cross-Platform Matching | ISRC only | Fallback search, manual mapping | MEDIUM | 1 week |
| 20 | Secrets Management | Keys in `Config.swift` | Move to build configs/secrets | SMALL | 1 day |

**Total P1 Effort:** ~15-17 weeks

---

### Priority 2 (P2) - IMPORTANT - Needed for Good UX

| # | Feature | Current State | Missing Implementation | Complexity | Estimate |
|---|---------|---------------|------------------------|-----------|----------|
| 21 | Group Chats/Phlocks | Stub button exists | Group creation, chat, playlists | LARGE | 3+ weeks |
| 22 | Comments UI | Backend exists, no UI | Display comments, composer | MEDIUM | 1 week |
| 23 | Reactions/Likes | None | Emoji reactions, counts | SMALL | 4 days |
| 24 | Profile Following | Mutual friends only | Follow without approval | MEDIUM | 1 week |
| 25 | @Mentions/Tagging | Plain text only | Tag friends, notifications | MEDIUM | 5 days |
| 26 | Onboarding Flow | None | Tutorial, sample content | MEDIUM | 1 week |
| 27 | Music Discovery Feed | Search only | Trending, recommendations | LARGE | 2 weeks |
| 28 | Profile Customization | Basic bio/photo | Genres, badges, themes | MEDIUM | 1 week |
| 29 | Listening Analytics | None | Personal stats, history | LARGE | 2 weeks |
| 30 | Share Analytics | No UI | Who played/saved, success rate | MEDIUM | 1 week |
| 31 | Image Caching | No cache | Disk cache, prefetch | SMALL | 3 days |
| 32 | Request Retry Logic | Fail once | Exponential backoff, queue | SMALL | 4 days |
| 33 | Rate Limiting | None | Client-side throttling | SMALL | 3 days |
| 34 | Memory Leaks | Unbounded cache | LRU eviction, size limits | SMALL | 2 days |

**Code Evidence for #34:** `UserService.swift:11-15` - userCache and friendsCache grow forever

**Total P2 Effort:** 14-16 weeks

---

### Priority 3 (P3) - NICE-TO-HAVE - Can Defer

| # | Feature | Current State | Missing Implementation | Complexity | Estimate |
|---|---------|---------------|------------------------|-----------|----------|
| 35 | Settings Screen | None | Notifications, data, language | MEDIUM | 1 week |
| 36 | Theme Customization | System only | Accent colors, fonts | SMALL | 4 days |
| 37 | Export/Backup | None | Export history, backup data | SMALL | 3 days |

**Total P3 Effort:** 2-3 weeks

---

## Part 3: Code Evidence - Files with Critical Issues

### Files with Placeholder/Broken Implementations

1. **`apps/ios/phlock/phlock/Views/Components/QuickSendBar.swift`**
   - Lines ~599-613: External sharing stubs (iMessage, Instagram); WhatsApp plain text.
   - Lines ~487-538: Group creation stub (does nothing).

2. **`apps/ios/phlock/phlock/Views/Main/FriendsView.swift`**
   - Lines ~150-260: Only manual search, no contact sync/invites.

3. **`apps/ios/phlock/phlock/Services/UserService.swift`**
   - Lines 11-15: Unbounded cache memory leak
   ```swift
   private var userCache: [UUID: User] = [:]
   private var friendsCache: [UUID: [User]] = [:]
   // These grow forever with no eviction policy
   ```

4. **`apps/ios/phlock/phlock/Services/AuthService_v2.swift`**
   - Lines ~641-645: Spotify artist search deferred (returns empty string)

5. **`apps/ios/phlock/phlock/Services/Config.swift`**
   - Real keys committed; needs build-config secrets.

6. **`supabase/migrations/20251201090000_create_notifications_table.sql`**
   - Schema supports only `friend_request_accepted`, `daily_nudge`; app expects more notification types.

### Missing Files/Components

- No `ContactsService.swift` (no contact integration)
- No `BlockedUsersService.swift` (no moderation)
- No Settings view
- No Onboarding flow views
- No Comment display views (despite backend support in `ShareService.swift`)
- No Associated Domains in `Info.plist` (no Universal Links)
- No deep link routing in `phlockApp.swift` beyond OAuth callback
- No push token registration/APNs handler; no `send-push-notification` edge function

---

## Part 4: Beta Launch Implementation Plan

### Goal
Get to a functional beta with real users sending music to each other within **6-8 weeks**.

### Scope
- Fix all P0 blockers
- Add must-have features: push notifications, comments UI, analytics

### Timeline Breakdown

---

### Phase 1: Core Functionality (Weeks 1-4)

#### Week 1: Friend Discovery System
**Objective:** Users can find and add friends via multiple methods

**Tasks:**
1. **Contact Sync Integration**
   - Add Contacts framework to project
   - Request contacts permission in onboarding
   - Create `ContactsService.swift` for CNContactStore integration
   - Hash phone numbers/emails for privacy-safe matching
   - Add phone/email fields to users table (hashed)
   - Implement contact matching algorithm

2. **Invite Link System**
   - Design invite link format: `https://phlock.app/invite/{user_id}`
   - Add Universal Links configuration (Part 1)
   - Generate shareable invite URLs
   - Track invite attribution in database
   - Add "Invite Friends" button to FriendsView

3. **Enhanced Username Search**
   - Improve search UX with suggestions
   - Add search history
   - Show mutual friends in results

4. **Social Media Import (Instagram/Facebook)**
   - Integrate Instagram Graph API for friend list
   - Add Facebook Login SDK
   - OAuth flow for social platforms
   - Match social profiles to Phlock users

**Deliverables:**
- Users can sync contacts and find friends
- Users can share invite links via any messaging app
- Username search is more discoverable
- Optional: Import Instagram/Facebook friends

**Files to Create:**
- `ContactsService.swift`
- `InviteService.swift`
- `SocialMediaImportView.swift`

**Files to Modify:**
- `FriendsView.swift` (add contact sync UI)
- `Info.plist` (add contacts permission)
- Database migration for phone/email columns

---

#### Week 2: External Sharing
**Objective:** Users can share tracks to iMessage, Instagram, WhatsApp with rich previews

**Tasks:**
1. **iMessage Sharing (Native iOS Share Sheet)**
   - Replace stub with `UIActivityViewController`
   - Generate rich link preview with track metadata
   - Create custom activity item for track sharing
   - Add track image and text formatting

2. **Instagram Stories Integration**
   - Implement Instagram Stories API via pasteboard
   - Create sticker asset with album art
   - Configure URL scheme (`instagram-stories://share`)
   - Design story background with gradient from album art
   - Fallback to Instagram DM if Stories unavailable

3. **Instagram DM Sharing**
   - Use generic share sheet with formatted message
   - Include deep link to track
   - Rich text formatting

4. **WhatsApp Enhancement**
   - Replace plain text with rich link
   - Include album art preview (via deep link)
   - Format message with track name and artist

**Deliverables:**
- Tap "iMessage" → Native iOS share sheet opens with track preview
- Tap "Instagram" → Instagram Stories opens with track sticker
- Tap "WhatsApp" → WhatsApp opens with rich formatted message
- All platforms include deep link back to Phlock

**Files to Create:**
- `ShareSheet.swift` (UIViewControllerRepresentable wrapper)
- `TrackActivityItem.swift` (custom UIActivityItemSource)
- `InstagramShareService.swift`

**Files to Modify:**
- `QuickSendBar.swift` (replace stubs with implementations)
- `Info.plist` (add LSApplicationQueriesSchemes for instagram-stories, whatsapp)

---

#### Week 3: Push Notifications (Part 1)
**Objective:** Users receive push notifications for new shares and friend requests

**Tasks:**
1. **APNs Setup**
   - Create APNs certificate in Apple Developer
   - Upload certificate to Supabase dashboard
   - Add Push Notifications capability to Xcode project

2. **Permission Flow**
   - Request notification permission in onboarding
   - Create permission prompt with value proposition
   - Handle permission states (granted, denied, not determined)

3. **Device Token Registration**
   - Register device token with APNs
   - Store token in Supabase (user_devices table)
   - Handle token updates

4. **Notification Handling**
   - Wire UNUserNotificationCenter delegate
   - Handle foreground/background notifications
   - Parse notification payload and navigate to content

**Deliverables:**
- Users prompted for notification permission
- Device tokens registered with Supabase
- App handles incoming notifications
- Tapping notification navigates to relevant content

**Files to Create:**
- `NotificationPermissionView.swift`
- Database migration for `user_devices` table

**Files to Modify:**
- `phlockApp.swift` (add UNUserNotificationCenter delegate)

---

#### Week 4: Push Notifications (Part 2) & Universal Links
**Objective:** Complete notification system and enable deep linking

**Tasks:**
1. **Supabase Edge Function for Notifications**
   - Create `send-push-notification` edge function
   - Trigger notifications on share creation
   - Trigger on friend request
   - Trigger on comment creation
   - Format notification payloads

2. **Badge Management**
   - Update badge count on new shares
   - Clear badge on app open
   - Sync badge with unread count

3. **In-App Notification Center**
   - Create notification history view
   - Mark notifications as read
   - Group notifications by type/date

4. **Universal Links Setup**
   - Add Associated Domains entitlement
   - Create `apple-app-site-association` file
   - Host AASA file on web server
   - Implement URL handling in `phlockApp.swift`
   - Parse track IDs and user IDs from URLs

**Deliverables:**
- Backend automatically sends push notifications
- Badge counts reflect unread shares
- Users can view notification history
- Track links and invite links open app directly

**Files to Create:**
- `supabase/functions/send-push-notification/index.ts`
- `NotificationCenterView.swift`
- `apple-app-site-association` (JSON file)

**Files to Modify:**
- `phlockApp.swift` (add deep link routing)
- Xcode project (add Associated Domains capability)

---

### Phase 2: Must-Have Features (Weeks 5-6)

#### Week 5: Comments UI & Social Features
**Objective:** Users can comment on shares and engage socially

**Tasks:**
1. **Comments Display**
   - Add comments section to share detail view
   - Fetch comments using existing `ShareService.getComments()`
   - Display comment threads with user avatars
   - Real-time updates for new comments

2. **Comment Composer**
   - Create comment input field
   - Implement character limit
   - Add emoji picker
   - Post comments using existing `ShareService.addComment()`

3. **Comment Notifications**
   - Send push notification on new comment
   - Show notification badge on shares with new comments
   - Navigate to comment from notification

4. **Comment Reactions (Optional)**
   - Like comments
   - Quick emoji reactions

**Deliverables:**
- Tap on share → See all comments
- Users can add comments to shares
- Receive notification when friend comments on your share
- Comments update in real-time

**Files to Create:**
- `ShareDetailView.swift` (with comments section)
- `CommentView.swift` (individual comment component)
- `CommentComposerView.swift` (input field)

**Files to Modify:**
- `FeedView.swift` (navigate to ShareDetailView on tap)
- `InboxView.swift` (navigate to ShareDetailView)

---

#### Week 6: Analytics & Insights
**Objective:** Users can see listening stats and share analytics

**Tasks:**
1. **Personal Listening Dashboard**
   - Create analytics view in Profile tab
   - Show total shares sent/received
   - Show most shared artists/tracks
   - Display listening trends over time
   - Friend activity summary

2. **Share Analytics**
   - Show who played your shares
   - Show who saved your shares
   - Calculate engagement rate (played/sent)
   - Show share success patterns (best time to send)

3. **Friend Compatibility Scores**
   - Calculate taste similarity based on shared artists
   - Show compatibility percentage with each friend
   - Highlight friends with similar taste

4. **Weekly Recap Notifications**
   - Generate weekly summary
   - Send push notification with highlights
   - "You sent 12 shares this week, 8 were played"

**Deliverables:**
- New "Analytics" section in Profile
- Tap on sent share → See who played/saved it
- View compatibility scores with friends
- Receive weekly recap notification

**Files to Create:**
- `AnalyticsView.swift`
- `ShareAnalyticsView.swift`
- `FriendCompatibilityView.swift`
- `supabase/functions/generate-weekly-recap/index.ts`

**Files to Modify:**
- `ProfileView.swift` (add Analytics button)

---

### Phase 3: Polish & Safety (Weeks 7-8)

#### Week 7: Privacy & Safety
**Objective:** Users can control privacy and block abusive users

**Tasks:**
1. **Block/Report Users**
   - Create `BlockedUsersService.swift`
   - Add block user functionality
   - Add report user flow
   - Hide blocked users from feed/search
   - Prevent blocked users from sharing with you

2. **Privacy Settings**
   - Create Settings view
   - Add "Private Account" toggle
   - Add "Hide Listening Activity" option
   - Add "Who Can Send Me Music" control
   - Add "Mute Notifications From" per-user setting

3. **Delete Account**
   - Add "Delete Account" to settings
   - Confirmation dialog with warning
   - Cascade delete user data
   - Optional: Export data before deletion (GDPR)

4. **Improved Error Handling**
   - Replace generic error alerts
   - Add user-friendly error messages
   - Add retry buttons on failures
   - Handle network offline state
   - Show offline indicator

**Deliverables:**
- Users can block/report others
- Privacy settings control visibility
- Users can delete their account
- Better error messages throughout app

**Files to Create:**
- `BlockedUsersService.swift`
- `SettingsView.swift`
- `PrivacySettingsView.swift`
- `DeleteAccountView.swift`

**Files to Modify:**
- All Service files (improve error handling)
- `ProfileView.swift` (add Settings button)

---

#### Week 8: Final Polish & Testing
**Objective:** App is stable and ready for beta users

**Tasks:**
1. **Token Refresh Edge Cases**
   - Test expired token scenarios
   - Implement automatic re-authentication
   - Handle revoked tokens gracefully
   - Background token refresh

2. **Offline Mode Basics**
   - Detect network offline state
   - Queue outgoing shares when offline
   - Show offline banner
   - Auto-retry when connection restored

3. **Memory Leak Fixes**
   - Fix unbounded cache in UserService
   - Implement LRU eviction
   - Add cache size limits
   - Profile memory usage

4. **Final Testing**
   - Test all user flows end-to-end
   - Test on multiple iOS versions
   - Test on different device sizes
   - Fix critical bugs
   - Performance optimization

5. **Beta Preparation**
   - Set up TestFlight
   - Create App Store listing (draft)
   - Write privacy policy
   - Create beta testing plan
   - Prepare user onboarding

**Deliverables:**
- App handles token expiration gracefully
- Basic offline support
- No memory leaks
- Beta-ready build uploaded to TestFlight

---

## Part 5: Success Criteria for Beta Launch

### Core Functionality
- ✅ Users can find friends via contacts, invite links, or username
- ✅ Users can share tracks to iMessage, Instagram, WhatsApp
- ✅ Users receive push notifications for shares and comments
- ✅ Users can comment on shares
- ✅ Users can view listening analytics

### Technical Quality
- ✅ App handles network errors gracefully
- ✅ No critical bugs or crashes
- ✅ Authentication works reliably
- ✅ Push notifications deliver consistently
- ✅ No memory leaks

### Safety & Privacy
- ✅ Users can block/report others
- ✅ Users can delete their account
- ✅ Basic privacy settings exist

### User Experience
- ✅ Clear error messages
- ✅ Smooth navigation
- ✅ Fast load times
- ✅ Intuitive UI

---

## Part 6: Features Deferred to Post-Launch

### Phase 2 (P1) Features - Next 3 Months
- Full track playback (Spotify SDK integration)
- Advanced offline mode with local cache
- Change music platform
- Account recovery options
- Content moderation system
- Cross-platform track matching improvements

### Phase 3 (P2) Features - Next 6 Months
- Group chats and group phlocks
- Reactions and likes on shares
- Profile following (non-mutual)
- @Mentions and tagging
- Music discovery feed with recommendations
- Advanced analytics and insights
- Listening party mode (synchronized playback)

### Phase 4 (P3) Features - Future
- Timestamped reactions during playback
- Gamification (leaderboards, badges, achievements)
- Weekly challenges
- Theme customization
- Export/backup functionality

---

## Part 7: Risk Mitigation

### High-Risk Areas

1. **Push Notifications Reliability**
   - Risk: APNs may fail or delay
   - Mitigation: Add in-app polling fallback, monitor delivery rates

2. **Contact Sync Privacy**
   - Risk: Users concerned about privacy
   - Mitigation: Clear permission messaging, hash contacts, opt-in only

3. **Instagram API Changes**
   - Risk: Instagram may change/deprecate APIs
   - Mitigation: Use official SDKs, fallback to generic share sheet

4. **Token Refresh Failures**
   - Risk: Users get logged out unexpectedly
   - Mitigation: Proactive token refresh, clear re-auth flow

5. **Database Performance**
   - Risk: Slow queries as user base grows
   - Mitigation: Add indexes, optimize queries, monitor performance

### Testing Strategy

1. **Week 1-6:** Continuous testing on simulator during development
2. **Week 7:** Testing on physical devices (multiple iOS versions)
3. **Week 8:** Internal beta with 5-10 team members
4. **Week 9:** External beta with 50-100 users via TestFlight
5. **Week 10-12:** Bug fixes and iteration based on feedback

---

## Part 8: Metrics to Track During Beta

### Engagement Metrics
- Daily/Weekly Active Users (DAU/WAU)
- Shares sent per user per day
- Share play rate (% of shares that get played)
- Share save rate (% of shares that get saved)
- Comments per share
- Average session duration

### Growth Metrics
- New user signups per day
- Friend connections per user
- Invite link shares
- Invite conversion rate
- Contact sync opt-in rate

### Technical Metrics
- Crash rate
- Push notification delivery rate
- API error rate
- Average load time
- Token refresh success rate

### Retention Metrics
- Day 1, Day 7, Day 30 retention
- Weekly share streak retention
- Churn rate

---

## Conclusion

The Phlock app has **37 critical missing features** that prevent it from being user-ready. The most critical blockers are:

1. **Friend discovery is broken** - Only manual username search exists
2. **External sharing is broken** - iMessage and Instagram are empty stubs
3. **No push notifications** - Users won't know when they receive shares

This implementation plan focuses on fixing these blockers plus adding must-have features (comments, analytics) to reach a functional beta in **6-8 weeks**.

After beta launch, the roadmap includes full track playback, group chats, advanced analytics, and gamification features over the following 6-12 months.

---

**Next Steps:**
1. Review and approve this plan
2. Set up project tracking (GitHub Issues or Jira)
3. Begin Week 1 implementation (Friend Discovery)
4. Weekly progress reviews and adjustments

**Questions or Feedback:** Ready to proceed with implementation.
