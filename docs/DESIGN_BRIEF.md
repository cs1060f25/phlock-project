# Phlock UI/UX Design Brief

## Overview

Phlock is a daily music curation app where each user picks **one song per day** and listens to a 5-person "phlock" playlist from friends they choose. This brief outlines the design requirements for four key screens: **Phlock (Home)**, **Friends**, **Notifications**, and **Profile**.

---

## Brand & Design System

### Typography
- **Headers & Hero Text:** Lora (serif)
- **Body Text:** DM Sans (sans-serif)

### Color Scheme
- Support both **light** and **dark** modes
- Primary accent color for CTAs and highlights
- Muted grays for secondary elements
- Success green for confirmation states (e.g., nudge sent, song saved)

### Visual Language
- Clean, minimal aesthetic
- Card-based layouts with subtle shadows
- Rounded corners (12-18px radius)
- Generous whitespace
- Avatar-centric for social elements

---

## Screen 1: Phlock (Home / Daily Playlist)

**Purpose:** The main screen where users view their daily playlist from their 5 phlock members and select their own daily song.

### Key States

#### 1. Gated State (User hasn't picked today's song)
- **Blur overlay** on the playlist content
- **Modal card** prompting user to pick their song:
  - Sparkle icon
  - "unlock today's playlist" headline
  - "choose today's song" primary CTA button
  - "share your pick to unlock the feed" subtext

#### 2. Active State (User has picked, viewing playlist)
- **Navigation title:** "your phlock" (large title, lowercase)
- **Song rows** showing phlock members' daily picks:
  - Album artwork (56x56) with play/pause overlay
  - Song title + artist name
  - Optional message in italics (scrollable horizontally if long)
  - **Actions on right:**
    - Swap button (circular arrows icon)
    - Add to library button (plus circle → checkmark when saved)
    - Member avatar (tappable to profile)

#### 3. Waiting State (Member hasn't picked yet)
- **Member avatar** (circular, 56x56)
- "Waiting for today's song..." in italics
- **Nudge button** (hand wave icon) - turns green/filled when nudged

#### 4. Empty Slot State (Less than 5 members)
- **Dashed placeholder** with plus icon
- "Add a friend to your phlock"
- "Add" button on right

#### 5. My Daily Song Section (at bottom)
- If selected: Card showing user's pick with sparkle badge "your daily pick"
- If not selected: Gradient card prompting "select your song of the day"

### Interactions
- Pull-to-refresh
- Tap album art to play/pause
- Swipe actions for additional options
- Toast notifications for actions (nudge sent, added to library, etc.)

---

## Screen 2: Friends

**Purpose:** Manage friendships, discover new users, and sync contacts.

### Sections (Top to Bottom)

#### 1. Search Bar
- Non-sticky, part of content scroll
- Magnifying glass icon + placeholder "Search friends..."
- Clear button when text present

#### 2. Friend Requests Section (conditional)
- **Horizontal scroll** of request cards
- Each card:
  - Circular profile photo (60x60)
  - Display name
  - "wants to connect" subtext
  - Accept (checkmark, dark bg) / Reject (X, light bg) buttons

#### 3. People on Phlock Section (when searching)
- Shows search results
- User rows with avatar, name, username/platform badge
- Empty state: magnifying glass icon + "No matches found"

#### 4. Your Friends Section
- **Sticky header** with "your friends" + count badge
- List of friend rows:
  - Avatar (48x48)
  - Display name
  - @username or platform indicator (Spotify/Apple Music logo)
- Empty state: person.2.slash icon + "No friends yet" + "Your crew starts here..."

#### 5. From Contacts Section
- **Banner CTA** to sync contacts (if not synced):
  - Blue circle with person badge icon
  - "find friends" title
  - "Sync contacts to find people you know" subtext
- If synced: List of matched users with "as [Contact Name]" badge
- Loading state: spinner + "Syncing contacts..."
- Error state: retry button

### Interactions
- Pull-to-refresh
- Tap row to navigate to user profile
- Debounced search as user types

---

## Screen 3: Notifications

**Purpose:** View activity including friend requests, nudges, and social updates.

### Layout

#### Empty State
- Bell slash icon in circle
- "All caught up" headline
- "When friends add you or nudge you for a song, you'll see it here."

#### Notification List
- **Grouped by time:** Today, Yesterday, This Week, [Date]
- **Section headers:** uppercase, secondary color

#### Notification Row Components
- **Unread indicator:** Blue dot on left (8px)
- **Avatar:** 44x44 circular
- **Text area:**
  - Attributed text with bold actor names
  - Relative timestamp below ("2h ago")
- **Action button** on right (contextual):
  - "View" (gray bg) - for friend request accepted
  - "Add" (blue bg) - for friend joined
  - "Listen" (gray bg) - for friend picked song
  - "Pick Song" (blue bg) - for daily nudge

### Notification Types
| Type | Message Format | Action |
|------|----------------|--------|
| Friend Request Accepted | **[Name]** accepted your friend request | View |
| Friend Request Received | **[Name]** sent you a friend request | View |
| Friend Joined | **[Name]** is on Phlock as @username | Add |
| Friend Picked Song | **[Name]** picked a song for today | Listen |
| Daily Nudge | **[Name]** nudged you to pick today's song | Pick Song |
| Daily Nudge (multiple) | **[Name1]**, **[Name2]**, and 3 others nudged you | Pick Song |
| Streak Milestone | You reached a new streak milestone! | - |

### Interactions
- Pull-to-refresh
- Tap row to mark as read + navigate
- Swipe to delete (trailing action)

---

## Screen 4: Profile

**Purpose:** View personal profile, stats, music activity, and settings.

### Sections (Top to Bottom)

#### 1. Header
- **Profile photo** (100x100 circular)
- **Display name** + platform logo (Spotify/Apple Music)
- **Bio** (if set)
- **Action links:** "edit profile" (pencil icon), "friends" (people icon)

#### 2. Today's Pick Card
- If selected:
  - Album artwork (80x80)
  - Song title + artist
  - Optional message in quotes
  - Play/pause button on right
  - Playing indicator bar on left when active
- If not selected:
  - "pick your song for today"
  - "keep your streak alive" with fire emoji
  - Plus circle button

#### 3. My Phlock Row
- **Horizontal scroll** of member avatars (60x60)
- Empty slots: dashed circle with plus icon
- Three-dot "edit" button at end

#### 4. Your Activity Section
- **Three stat pills** in row:
  - Send streak (flame icon) + days count + "days in a row"
  - Phlocks (custom glyph) + count + "you're in"
  - Saves (plus circle) + count + "from your shares"

#### 5. Top Artists Sent Card
- Numbered list (1-3)
- Artist name + send count
- External link button to open in Spotify/Apple Music

#### 6. Top Genres Card
- List with horizontal bar charts
- Genre name + count
- Bar width proportional to max

#### 7. What I'm Listening To (from platform)
- Numbered list of recent tracks
- Album art (40x40) + track name + timestamp
- Play/pause button on right
- "show more" / "show less" toggle if >5 items

#### 8. Who I'm Listening To (from platform)
- Similar format for top artists
- Circular avatar (40x40)
- External link button

#### 9. Past Picks
- List of previous daily songs
- Album art (40x40) + track name + artist + date

#### 10. Footer
- Version info + "TestFlight Beta"
- Settings gear icon in nav bar (top right)

### Interactions
- Pull-to-refresh to reload platform data
- Tap track to play
- Tap phlock member to view profile
- Tap artist to open in streaming platform

---

## Shared Components

### Mini Player
- **Persistent bar** at bottom when music playing
- Album art + track info + play/pause + close
- Tap to expand full-screen player

### Toast Notifications
- Success (green), Error (red), Info (gray) variants
- Brief message + icon
- Auto-dismiss after 3s

### Profile Photo Placeholder
- Circle with gradient
- First letter of display name

### User Row (reusable)
- Avatar (48x48)
- Name + username or platform badge
- Chevron or action on right

### Loading States
- Centered spinner with optional subtext
- Skeleton placeholders for lists

### Error States
- Icon + headline + retry button

---

## Swap & Add Member Sheets

### Swap Member Sheet
- **Header:** Current member photo + "Swap [Name] with..."
- **List:** Available friends (not in phlock)
  - Avatar + name + username
  - Green/gray dot indicating if they've picked today
  - Checkmark when selected
- **Actions:** Cancel (left), Confirm Swap (right)

### Add Member Sheet
- Similar to swap but titled "Add to Phlock"
- "Add" button instead of "Confirm Swap"

---

## Phlock Swap Behavior Note

**Important:** When a user swaps a phlock member:
- If the member **has already picked** their song for the day → swap takes effect at **midnight**
- If the member **hasn't picked yet** → swap is **immediate**

The UI should communicate this clearly (toast message: "Swapping [old] for [new] at midnight" vs "Swapped [old] for [new]").

---

## Deliverables Requested

1. **High-fidelity mockups** for all four screens (light + dark mode)
2. **Component library** with reusable elements
3. **Empty, loading, and error states** for each screen
4. **Interaction specifications** for key flows
5. **Annotations** explaining design decisions

---

## Reference

**Current Implementation:** SwiftUI + iOS 16+
**Design Files Location:** [TBD]
**Figma/Sketch Access:** [TBD]

---

*Last Updated: November 27, 2025*
