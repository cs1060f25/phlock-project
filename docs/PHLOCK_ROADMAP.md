# Phlock Roadmap (Archived - musiclinkr era)

**Status:** Historical context from the pre-iOS (React Native/musiclinkr) vision. For the active daily curation plan and production blockers, see `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md` and `claude.md`.

**Last Updated:** October 15, 2025
**Document Purpose:** Strategic roadmap for evolving musiclinkr into the full Phlock peer-to-peer music discovery network

---

## Executive Summary

**Current State:** musiclinkr is a cross-platform music link converter (React Native + Expo)
**Target State:** Phlock - a social infrastructure layer that makes peer music recommendations measurable and rewarding
**Timeline:** 18-24 months to full platform
**Key Insight:** 60% of technical foundation already built; behavioral validation is the primary risk

**Core Value Proposition:**
- Make music sharing work seamlessly across platforms (Spotify, Apple Music, etc.)
- Provide visible feedback through "phlocks" (network visualizations)
- Give artists intelligence about their advocates
- Democratize discovery for long-tail artists

---

## Current Foundation (What We Have)

### musiclinkr Assets
- ✅ Cross-platform track resolution (Spotify, Apple Music, YouTube, Amazon, Tidal, SoundCloud)
- ✅ React Native + Expo infrastructure
- ✅ API integration layer for multiple streaming services
- ✅ Basic UI/UX patterns
- ✅ Track search and metadata handling
- ✅ Universal Track ID (UTID) system for cross-platform mapping

### What This Gives Us
- **60% of technical foundation** for Phlock already built
- **Hardest problem solved:** Cross-platform compatibility
- **Proven patterns:** API integration, track resolution, fuzzy matching
- **Working codebase:** Can iterate rather than rebuild

### What We Need to Add
- User authentication and social graph
- Share transaction tracking
- Notification system
- Visualization engine for phlocks
- Influence scoring algorithm
- Artist dashboard
- Monetization layer

---

## Phase 1: Social MVP (Months 1-3)

**Goal:** Transform musiclinkr from a utility into a social sharing platform
**Key Question:** *Will users share music deliberately with daily constraints?*

### 1.1 User Authentication & Social Graph

**Technical Stack:**
- Firebase Auth or Supabase Auth
- Phone number/contact syncing (expo-contacts)
- Friend discovery and management

**Features to Build:**
- [ ] Email/phone authentication
- [ ] User profiles (name, photo, bio)
- [ ] Friend requests/contacts import
- [ ] "Find friends" by phone/email
- [ ] Privacy controls (who can send to me)

**Database Schema:**
```sql
users {
  id: uuid (primary key)
  phone: string
  email: string
  display_name: string
  profile_photo_url: string
  created_at: timestamp
}

friendships {
  id: uuid (primary key)
  user_id_1: uuid (foreign key)
  user_id_2: uuid (foreign key)
  status: enum('pending', 'accepted', 'blocked')
  created_at: timestamp
}
```

**Success Metrics:**
- 70%+ of users add at least 3 friends
- Average friend count: 8-12
- <5% friend request rejection rate

---

### 1.2 Transform Link Conversion into Sharing

**Current Flow:**
```
User pastes link → Convert → Copy new link
```

**New Flow:**
```
User searches/selects track → Choose recipient → Send → Recipient gets notification → Opens in their app
```

**Technical Changes:**
- [ ] Replace "Convert" button with "Send to Friend" selector
- [ ] Add friend picker UI component
- [ ] Implement push notifications (Expo Notifications)
- [ ] Create inbox/feed view for received tracks
- [ ] Track share transactions in database

**Database Schema:**
```sql
shares {
  id: uuid (primary key)
  sender_id: uuid (foreign key → users)
  recipient_id: uuid (foreign key → users)
  utid: string (our existing track ID)
  platform_sent_from: string (spotify/apple/etc)
  timestamp: timestamp
  status: enum('sent', 'received', 'played', 'saved', 'forwarded', 'dismissed')
  message: text (optional note from sender)
}
```

**UI Components:**
- FriendSelector (modal with search)
- ShareConfirmation (preview before sending)
- InboxCard (shows received track)
- SendButton (replaces Convert button)

**Success Metrics:**
- Average 3+ sends per user per week
- <10% share failure rate
- 80%+ notification open rate

---

### 1.3 The Crate - Your Social Discovery Timeline

**What It Is:** A social discovery timeline/journal - NOT just another music library

**Key Insight:** Users already have native library/playlists. The Crate's value is the *social context* and *discovery story*, not just the music.

#### Positioning: Social Discovery Journal

**The Crate tells a story:**
- Who introduced you to this song
- When they shared it (timeline view)
- Why they sent it (conversation thread - see Section 2.5)
- Who else discovered it through you (if you forwarded)

**This is NOT:**
- ❌ Another Spotify/Apple Music library
- ❌ A generic playlist
- ❌ A "Liked Songs" clone
- ❌ Just storage

**This IS:**
- ✅ A sentimental archive of musical moments
- ✅ A timeline of your discovery journey
- ✅ A social context layer on top of music
- ✅ A way to remember who shaped your taste

#### MVP Features

**Core Functionality:**
- [ ] Timeline view (chronological, most recent first)
- [ ] Rich card design showing:
  - Album art
  - Track + artist info
  - "Sent by [Name] on [Date]"
  - Sender's message (if included - see Section 2.5)
  - Your reply (if you sent one)
- [ ] Tap to play (opens in native streaming app)
- [ ] Swipe to remove
- [ ] Multiple senders indicator: "Also sent by [Name], [Name]"
- [ ] Filter by:
  - Sender (show all from one friend)
  - Time period (this week, this month, all time)
  - Conversation (songs with messages)

**Social Features:**
- [ ] Tap conversation bubble to view full thread
- [ ] Quick reply from Crate view
- [ ] Forward button (send to another friend)
- [ ] "Thank them" button → opens chat/message app

**Auto-Sync to Native Playlist (Functional Benefit):**
- [ ] Option: "Auto-sync Crate to Spotify/Apple Music playlist"
- [ ] Creates a playlist called "Phlock Crate"
- [ ] Automatically adds/removes songs as Crate changes
- [ ] Now Crate has functional value beyond sentiment

**Visual Design:**

```
┌─────────────────────────────────────┐
│  Your Crate  (24 songs)        [⚙️]│
├─────────────────────────────────────┤
│                                     │
│  ╔═══════════════════════════════╗ │
│  ║ [Album Art]  Song Title       ║ │
│  ║              Artist Name      ║ │
│  ║                               ║ │
│  ║ 💬 "you HAVE to hear this" ║ │
│  ║ — Alex, 2 hours ago           ║ │
│  ║                               ║ │
│  ║ ▶️  🔁  💾  ⋯              ║ │
│  ╚═══════════════════════════════╝ │
│                                     │
│  ╔═══════════════════════════════╗ │
│  ║ [Album Art]  Song Title       ║ │
│  ║              Artist Name      ║ │
│  ║                               ║ │
│  ║ Sent by Jordan                ║ │
│  ║ Yesterday at 11:32pm          ║ │
│  ║                               ║ │
│  ║ ▶️  🔁  💾  ⋯              ║ │
│  ╚═══════════════════════════════╝ │
│                                     │
└─────────────────────────────────────┘
```

**Empty State (Important!):**

When Crate is empty:
```
Your Crate is where special songs live.

When a friend sends you a song you love,
save it here to remember who shared it
and why it mattered.

🎵 It's not just music - it's the story
   of how you discovered it.

[View Inbox] [Find Friends]
```

#### Technical Implementation

**Database Schema:**
```sql
crate_entries {
  id: uuid (primary key)
  user_id: uuid (foreign key → users)
  share_id: uuid (foreign key → shares)
  added_at: timestamp
  removed_at: timestamp (null if still in Crate)

  -- Playlist sync
  synced_to_playlist: boolean
  native_playlist_id: string (Spotify/Apple playlist ID)
}
```

**Playlist Auto-Sync Logic:**
```javascript
// When user enables auto-sync
async function enableCrateSync(userId, platform) {
  // Create playlist in native platform
  const playlist = await createPlaylist(userId, platform, {
    name: 'Phlock Crate',
    description: 'Songs from friends, synced from Phlock',
    public: false
  })

  // Add all current Crate songs
  const crateSongs = await getCrateSongs(userId)
  await addToPlaylist(playlist.id, crateSongs.map(s => s.track_id))

  // Save playlist ID
  await db.users.update(userId, {
    crate_sync_enabled: true,
    crate_playlist_id: playlist.id,
    crate_playlist_platform: platform
  })
}

// When user adds song to Crate
async function addToCrate(userId, shareId) {
  await db.crate_entries.create({ user_id: userId, share_id: shareId })

  // If sync enabled, add to playlist
  const user = await db.users.find(userId)
  if (user.crate_sync_enabled) {
    const share = await db.shares.find(shareId)
    await addToPlaylist(user.crate_playlist_id, [share.track_id])
  }
}
```

#### Why Users Will Choose Crate Over Native Library

**Native Library (Spotify/Apple):**
- Just a list of songs
- No context on how you found them
- No connection to who shared
- Generic, impersonal

**Phlock Crate:**
- Timeline of discovery moments
- Every song has a story
- Connected to friendships
- Personal, meaningful
- PLUS auto-syncs to native playlist anyway!

**Value Props:**
1. **Sentimental value:** "Remember when Alex sent me this the night before my graduation?"
2. **Social credit:** Track who influences your taste
3. **Discovery journal:** See your musical journey over time
4. **Functional:** Auto-syncs to native playlist
5. **Conversational:** Messages attached to songs

#### Settings & Preferences

**Crate Settings:**
- [ ] Toggle auto-sync (on/off)
- [ ] Choose sync platform (Spotify/Apple/both)
- [ ] Crate size limit (optional: 100 songs for free, unlimited for premium)
- [ ] Auto-remove after X days (optional)
- [ ] Privacy: Who can see your Crate (friends/private)

#### Success Metrics

- 40%+ of received tracks saved to Crate
- Users return to Crate 3+ times per week (up from 2+)
- Average Crate size: 30-70 tracks after 1 month (higher than just "library")
- 50%+ of users enable auto-sync within first week
- Qualitative: Users describe Crate as "sentimental" not "utility"

**Key Questions to Validate:**
- Do users perceive Crate as different from their native library?
- Does auto-sync increase save rate?
- Do conversations make songs more memorable?
- Would users pay to keep unlimited Crate storage?

---

### 1.4 Daily Send Limits

**The Rule:** Each user can send exactly 1 track to each friend per 24-hour period

**Implementation:**
```javascript
// Before allowing send
const sendsToday = await db.shares
  .where('sender_id', userId)
  .where('recipient_id', recipientId)
  .where('timestamp', '>', twentyFourHoursAgo)
  .count()

if (sendsToday >= 1) {
  const lastSend = await getLastSend(userId, recipientId)
  const hoursRemaining = 24 - hoursSince(lastSend)
  throw new Error(`You can send another song to ${recipientName} in ${hoursRemaining}h`)
}
```

**UI Treatment:**
- Show countdown timer in friend picker
- Use intentional language: "Your daily song for [Name]"
- Gray out unavailable friends with "Available in 4h 23m"
- Never make it feel punishing—frame as making each share special

**A/B Tests to Run:**
- Limit vs no limit (does constraint increase engagement?)
- 1 vs 2 vs 3 sends per day
- Rolling 24h vs daily reset at midnight

**Success Metrics:**
- Users *don't* complain about limits
- Engagement increases or stays stable with limits
- Saved rate increases (higher perceived value per share)

---

### 1.5 In-App Preview Playback

**The Opportunity:** Both Spotify and Apple Music APIs provide 30-second preview URLs that we can play directly in Phlock

**Why This Matters:** Users can hear songs *without leaving the app* - massive UX improvement and friction reducer

#### What's Possible

**Spotify API:**
```json
{
  "id": "track_id",
  "name": "Song Title",
  "preview_url": "https://p.scdn.co/mp3-preview/...",  // 30-second MP3
  "duration_ms": 240000
}
```
- **Format:** MP3
- **Duration:** ~30 seconds
- **Authentication:** No user auth required (public URLs)
- **Availability:** Most tracks (some `preview_url` fields are `null`)

**Apple Music API:**
```json
{
  "id": "track_id",
  "attributes": {
    "name": "Song Title",
    "previews": [{
      "url": "https://audio-ssl.itunes.apple.com/...",
      "duration": 30000  // milliseconds
    }]
  }
}
```
- **Format:** M4A (AAC)
- **Duration:** 30-90 seconds typically
- **Authentication:** Developer token only
- **Availability:** Most tracks have previews

#### User Experience Benefits

**Before (without preview):**
```
User receives song notification
  ↓
Opens Phlock
  ↓
Sees song in inbox
  ↓
Must tap "Open in Spotify" to hear it
  ↓
Leaves Phlock → Opens Spotify → Finds track → Plays
  ↓
Comes back to Phlock to save/forward
```

**After (with preview):**
```
User receives song notification
  ↓
Opens Phlock
  ↓
Sees song in inbox
  ↓
Taps ▶️ → Hears 30-second preview instantly
  ↓
[Save to Crate] or [Forward] or [Open Full Track in Spotify]
```

**Impact:** Reduces friction from 5+ steps to 1 tap. Decision-making becomes faster and more informed.

#### Where to Add Preview Playback

**1. Inbox (Priority #1)**
```
┌─────────────────────────────────────┐
│  New from Alex                      │
│                                     │
│  [Album Art]  Song Title            │
│               Artist Name           │
│                                     │
│  ▶️  0:00 ──────○──── 0:30        │
│                                     │
│  💬 "you HAVE to hear this!"       │
│                                     │
│  [Save to Crate]  [Forward]  [...]│
└─────────────────────────────────────┘
```

**2. Crate (Priority #2)**
- Scrub through 30-second previews
- "Play All Previews" feature (preview playlist)
- Quick way to revisit songs in Crate

**3. Share Preview (Priority #3)**
- Before sending, sender can preview the song
- Ensures they're sending the right track

#### UI/UX Design

**Audio Player Component:**
```javascript
<AudioPreviewPlayer
  previewUrl={track.preview_url}
  trackName={track.name}
  artistName={track.artist}
  albumArt={track.album_art}
  fallbackUrl={track.spotify_url}  // If no preview
/>
```

**Player States:**
- ▶️ Ready to play
- ⏸️ Paused
- 🔄 Loading...
- ❌ Preview unavailable → [Open in Spotify]

**Visual Design:**
- Minimal, embedded player (not full-screen modal)
- Scrubber bar shows progress
- Auto-stops at 30 seconds
- Auto-pauses when user scrolls away
- Only one preview playing at a time

#### Technical Implementation

**React Native Audio Libraries:**
```
Option 1: expo-av (Expo built-in)
- ✅ Simple API
- ✅ Works with Expo managed workflow
- ✅ Supports streaming from URL
- ✅ Built-in controls

Option 2: react-native-track-player
- ✅ Better performance
- ✅ Background playback
- ⚠️ More complex setup
- ⚠️ May require bare workflow
```

**Recommended:** Start with `expo-av` for Phase 1 (simpler, faster to implement)

**Code Example:**
```javascript
import { Audio } from 'expo-av';

const AudioPreviewPlayer = ({ previewUrl, fallbackUrl }) => {
  const [sound, setSound] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [position, setPosition] = useState(0);
  const [duration, setDuration] = useState(30000); // 30 seconds

  // Check if preview is available
  if (!previewUrl) {
    return (
      <TouchableOpacity onPress={() => Linking.openURL(fallbackUrl)}>
        <Text>Preview not available - Open in Spotify</Text>
      </TouchableOpacity>
    );
  }

  const playPause = async () => {
    if (sound) {
      if (isPlaying) {
        await sound.pauseAsync();
      } else {
        await sound.playAsync();
      }
      setIsPlaying(!isPlaying);
    } else {
      // Load and play
      const { sound: newSound } = await Audio.Sound.createAsync(
        { uri: previewUrl },
        { shouldPlay: true },
        onPlaybackStatusUpdate
      );
      setSound(newSound);
      setIsPlaying(true);
    }
  };

  const onPlaybackStatusUpdate = (status) => {
    if (status.isLoaded) {
      setPosition(status.positionMillis);
      setDuration(status.durationMillis);

      if (status.didJustFinish) {
        setIsPlaying(false);
        setPosition(0);
      }
    }
  };

  // Cleanup on unmount
  useEffect(() => {
    return sound ? () => { sound.unloadAsync(); } : undefined;
  }, [sound]);

  return (
    <View style={styles.player}>
      <TouchableOpacity onPress={playPause}>
        {isPlaying ? <PauseIcon /> : <PlayIcon />}
      </TouchableOpacity>

      <Slider
        value={position}
        maximumValue={duration}
        onValueChange={(val) => sound?.setPositionAsync(val)}
        style={styles.slider}
      />

      <Text>{formatTime(position)} / {formatTime(duration)}</Text>
    </View>
  );
};
```

#### Database Schema Updates

Track preview playback for analytics:

```sql
track_previews {
  id: uuid (primary key)
  user_id: uuid (foreign key → users)
  share_id: uuid (foreign key → shares)
  preview_url: string
  played_at: timestamp
  play_duration_ms: integer  // How long they actually listened
  completed: boolean  // Did they listen to the full 30 seconds?
}
```

#### Fallback Handling

**Not all tracks have previews** - graceful degradation:

```javascript
if (track.preview_url) {
  return <AudioPreviewPlayer previewUrl={track.preview_url} />;
} else {
  return (
    <View style={styles.noPreview}>
      <Text>Preview not available</Text>
      <Button
        title="Open in Spotify"
        onPress={() => Linking.openURL(track.spotify_url)}
      />
    </View>
  );
}
```

**Estimated Coverage:**
- Spotify: 70-80% of tracks have previews
- Apple Music: 85-90% of tracks have previews

#### Performance Considerations

**Memory Management:**
- Only load one preview at a time
- Unload audio when user navigates away
- Preload next preview in background (optional optimization)

**Network:**
- Previews are 400-700KB typically (30s of compressed audio)
- Cache previews locally (optional)
- Show loading state while buffering

**Battery:**
- Stop playback when app goes to background
- Auto-pause when user scrolls to different track

#### Success Metrics

**Engagement:**
- 60%+ of inbox songs get previewed before action taken
- Preview → Save conversion: 50%+ (vs. 40% without preview)
- Preview → Forward conversion: 15%+ (vs. 10% without preview)
- Average listen duration: 15-20 seconds (out of 30)

**Technical:**
- Preview load time: <2 seconds
- Preview availability rate: 75%+
- Audio playback error rate: <5%

**User Satisfaction:**
- Users describe preview as "essential" or "very helpful"
- Reduced "opened in native app but didn't like the song" friction
- Increased time in app (users stay to preview vs. leaving immediately)

#### A/B Tests to Run

- **Preview enabled vs. disabled:** Does preview increase save rate?
- **Auto-play vs. manual play:** Should preview auto-play when notification opened?
- **Preview length:** If we could choose, would 15 seconds be enough? Or need full 30?

#### Phase 1 Priority

**Recommendation:** Build this in Phase 1 alongside Inbox and Crate

**Why:**
- Relatively simple to implement (expo-av is straightforward)
- APIs already provide the data (no additional API work needed)
- Massive UX improvement with minimal complexity
- Critical for reducing friction in core flow
- Differentiates Phlock from "just another social app"

**Implementation Order:**
1. Inbox preview player (Week 2-3 of Phase 1)
2. Crate preview player (Week 3-4 of Phase 1)
3. Share preview (Week 4 of Phase 1)

---

### Phase 1 Success Criteria
- [ ] 1,000 active users
- [ ] 50% week-2 retention
- [ ] Average 3 sends per user per week
- [ ] 40%+ save-to-Crate rate
- [ ] Qualitative: Users describe sharing as "deliberate" and "meaningful"

---

## Phase 2: Feedback Loops & Retention (Months 3-5)

**Goal:** Create dopamine loops that drive sustained engagement
**Key Question:** *Does feedback increase sharing frequency?*

### 2.1 Engagement Signals

**Track These Actions:**
- **Played** - Recipient tapped to listen
- **Saved** - Added to Crate
- **Forwarded** - Passed song to someone else
- **Dismissed** - Swiped away/marked not interested

**⚠️ Important Design Decision (Uncertain):**
The idea of requiring users to save a song to their Crate before being allowed to forward it is **OPTIONAL/UNCERTAIN** and NOT required for Phase 1 MVP. This requirement could act as a quality gate to ensure only valued songs spread, but it may also create friction that discourages sharing. Decision on this feature is postponed pending user testing.

**Database Schema:**
```sql
engagements {
  id: uuid (primary key)
  share_id: uuid (foreign key → shares)
  user_id: uuid (who took the action)
  action: enum('played', 'saved', 'forwarded', 'dismissed')
  timestamp: timestamp
}
```

**Tracking Implementation:**
- [ ] Log play when user opens track in streaming app
- [ ] Log save when added to Crate
- [ ] Log forward when user reshares
- [ ] Log dismiss on swipe/close

**Success Metrics:**
- 80%+ of shares get played
- 40%+ get saved
- 10%+ get forwarded
- <20% get dismissed

---

### 2.2 Sender Notifications - Hybrid Strategy

**The Missing Feedback Loop:** When recipient engages, notify sender to create dopamine loop

**Hybrid Approach:** Real-time for high-value + daily digest for metrics

#### Real-Time Notifications (Immediate)

**Trigger instantly when:**
- 🔥 **Crate save:** "[Name] saved your song to their Crate"
- 🔗 **Forward:** "[Name] shared your song with 2 others!"
- 🎵 **New song received:** "Alex just sent you a song!"
- 💬 **Conversation reply:** "[Name] replied to your message"

**Why Real-Time:**
- High-value actions deserve immediate reinforcement
- Creates tight feedback loop (action → dopamine)
- Drives continued engagement

**Important:** ❌ Do NOT send automatic thank-you notifications from recipient to sender. The save notification itself is sufficient validation for the sender.

#### Daily Digest Notification (9:00 AM)

**Sent once per day at 9am user local time:**

```
Good morning! Here's your music impact from yesterday:

📊 3 people added your songs to their library
   • "Song Title" by Artist → 2 saves
   • "Song Title 2" by Artist 2 → 1 save

🎯 Your songs were opened 12 times
👥 You reached 8 people yesterday

[View Details]
```

**Why Daily Digest:**
- Library detection runs at 9am (batch job)
- Creates consistent daily ritual
- Reduces notification fatigue
- Aggregates lower-value metrics

**⚠️ Note:** Daily digest notification copy needs refinement - this is placeholder text.

**What Goes in Daily Digest:**
- Library adds detected via batch job (see Section 2.4)
- Aggregate open/play counts
- Reach stats (unique recipients)
- Weekly milestones (if applicable)

**What Does NOT Go in Digest:**
- High-value actions (those are real-time)
- Urgent notifications
- Social interactions

#### Implementation Details

**Technical Stack:**
- [ ] Push notifications via Expo Notifications
- [ ] In-app notification center
- [ ] Quiet hours respect (no notifications 10pm-8am)
- [ ] Notification preferences (let users customize)

**Scheduling:**
```javascript
// Real-time notifications
async function notifyRealTime(userId, type, data) {
  await expo.sendPushNotification({
    to: userId,
    title: getNotificationTitle(type, data),
    body: getNotificationBody(type, data),
    data: { type, ...data }
  })
}

// Daily digest - triggered by cron at 9am
async function sendDailyDigest() {
  const users = await db.users.where('digest_enabled', true)

  for (const user of users) {
    const yesterday = getYesterdayRange(user.timezone)

    const librarySaves = await getDetectedLibrarySaves(user.id, yesterday)
    const opens = await getOpens(user.id, yesterday)
    const reach = await getUniqueRecipients(user.id, yesterday)

    if (librarySaves.length > 0 || opens > 0) {
      await sendDigestNotification(user, {
        librarySaves,
        opens,
        reach
      })
    }
  }
}
```

**User Controls:**
- Toggle real-time notifications on/off
- Toggle daily digest on/off
- Set quiet hours window
- Mute specific friends
- Frequency preferences (immediate, batched, digest-only)

**Success Metrics:**
- 70%+ notification open rate
- Users who receive notifications share 2x more
- <5% notification opt-out rate
- Daily digest open rate >40%
- Real-time notification engagement >60%

---

### 2.3 Simple Influence Metrics

**Don't build full scoring yet—start with basic stats:**

**Show Users:**
- "Your songs reached 14 people this week"
- "3 people saved your recommendations"
- "Your song started a chain reaction 🔗 (3 forwards)"
- "Most influential share: [Song Name] → 8 people"

**Display Locations:**
- User profile
- Post-share confirmation ("Nice! 8 people have discovered this artist through you")
- Weekly email digest

**Technical Implementation:**
```sql
-- Simple aggregation queries
SELECT COUNT(DISTINCT recipient_id) as reach
FROM shares
WHERE sender_id = ? AND timestamp > ?

SELECT COUNT(*) as saves
FROM shares s
JOIN crate_entries c ON s.id = c.share_id
WHERE s.sender_id = ?
```

**Success Metrics:**
- Users check their stats 2+ times per week
- Stats viewing correlates with increased sharing
- Users screenshot/share their stats

---

### 2.4 Native Library Detection

**The Challenge:** How do we know if recipients actually saved shared songs to their native streaming library (Spotify, Apple Music)?

**The Solution:** Baseline check + periodic polling via streaming platform APIs

**How It Works:**

```javascript
// Step 1: Baseline check when sending
async function sendSong(senderId, recipientId, trackId) {
  // Check if recipient already has this song in their library
  const alreadySaved = await spotify.checkSaved(recipientId, trackId)

  await db.shares.create({
    sender_id: senderId,
    recipient_id: recipientId,
    track_id: trackId,
    recipient_had_saved: alreadySaved, // Baseline state
    recipient_saved_detected: false,
    last_library_check: new Date(),
    stop_checking_at: addDays(new Date(), 7) // Stop after 7 days
  })
}

// Step 2: Daily batch job at 9am
async function batchCheckLibraries() {
  const pendingShares = await db.shares
    .where('recipient_had_saved', false)
    .where('recipient_saved_detected', false)
    .where('stop_checking_at', '>', new Date())

  // Group by recipient to batch API calls
  const byRecipient = groupBy(pendingShares, 'recipient_id')

  for (const [recipientId, shares] of Object.entries(byRecipient)) {
    // Batch up to 50 tracks per request (Spotify limit)
    const trackIds = shares.map(s => s.track_id).slice(0, 50)
    const savedStatus = await spotify.checkSaved(recipientId, trackIds)

    shares.forEach((share, idx) => {
      if (savedStatus[idx] && !share.recipient_had_saved) {
        // They saved it! This is new
        recordLibrarySave(share.id)
        notifySender(share.sender_id, share.recipient_id, share.track_id)
      }
    })

    // Update last check timestamp
    await updateLastCheck(shares.map(s => s.id))
  }
}
```

**API Endpoints:**
- **Spotify:** `GET /v1/me/tracks/contains?ids={track_ids}`
  - Returns: `[true, false, true, ...]` for each track
  - Rate limit: 50 tracks per request

- **Apple Music:** `GET /v1/me/library/songs/{id}`
  - Check if song exists in user's library
  - Batch via multiple IDs

**Database Schema Updates:**

```sql
shares {
  id: uuid (primary key)
  sender_id: uuid (foreign key → users)
  recipient_id: uuid (foreign key → users)
  utid: string
  platform_sent_from: string
  timestamp: timestamp
  status: enum('sent', 'received', 'played', 'saved', 'forwarded', 'dismissed')
  message: text (optional note from sender)

  -- Library detection fields
  recipient_had_saved: boolean (baseline: did they already have it?)
  recipient_saved_detected: boolean (did we detect they added it?)
  saved_detected_at: timestamp (when did we detect it?)
  last_library_check: timestamp (last time we checked)
  stop_checking_at: timestamp (stop checking after 7 days)
}
```

**Cron Job Schedule:**
- **Frequency:** Once per day at 9:00 AM user local time
- **Duration:** ~5-10 minutes for 10,000 active shares
- **Rate limiting:** Batch 50 tracks per user, respect API limits
- **Optimization:** Only check shares from last 7 days

**Notification Flow:**
```
9:00 AM: Batch job runs
  ↓
Detect 3 new library saves for User A
  ↓
Queue notification: "Good morning! 3 people added your songs to their library yesterday"
  ↓
Include in daily digest notification
  ↓
Sender sees their impact, gets dopamine hit
```

**Why This Works:**
- ✅ Non-invasive (doesn't require "Recently Played" access)
- ✅ Accurate (baseline prevents false positives)
- ✅ Efficient (batched API calls, daily schedule)
- ✅ Scalable (stops checking after 7 days)
- ✅ User-friendly (creates daily ritual at consistent time)

**Limitations & Edge Cases:**
- Users who unlike/remove songs: We'll detect false negatives (can't track removals)
- Private sessions: Some platforms allow private listening (can't detect)
- Delayed saves: If user saves 8+ days later, we miss it (acceptable tradeoff)
- API changes: Dependent on platform maintaining these endpoints

**Success Metrics:**
- 30%+ of shared songs detected as saved to native library
- <1% false positive rate (verified via user reports)
- Batch job completes in <10 minutes
- 90%+ API success rate (no rate limit errors)

---

### 2.5 Conversation Features (Limited by Design)

**The Vision:** Allow lightweight, music-focused conversations without becoming a messaging platform

**Critical Constraint:** This is NOT a messaging app. Conversations are severely limited to maintain focus on music sharing.

#### Conversation Rules

**Strict Limits:**
1. **One message per side maximum**
   - Sender can include ONE message when sending the song
   - Recipient can reply ONCE
   - No back-and-forth beyond that
   - No group conversations

2. **Character limit: ~280 characters (tweet-length)**
   - Forces concise, thoughtful messages
   - Prevents long-form chatting
   - Maintains music-first focus

3. **Optional, not required**
   - Users can send songs without messages
   - Messages enhance context but aren't mandatory

**Example Flow:**
```
Alex sends song to Jordan:
"This reminded me of that night in Brooklyn 🌙"
(max 280 chars)

Jordan can reply ONCE:
"omg yes! adding this to my late night playlist"
(max 280 chars)

[Conversation ends - no further replies possible]
```

#### Database Schema

```sql
messages {
  id: uuid (primary key)
  share_id: uuid (foreign key → shares)
  sender_id: uuid (foreign key → users)
  recipient_id: uuid (foreign key → users)
  message_text: text (max 280 chars)
  message_type: enum('share_message', 'reply')
  timestamp: timestamp
}

-- Constraint: Only 2 messages max per share_id
-- (1 share_message + 1 reply)
```

#### UI/UX Design

**When Sending:**
- Optional text field below song preview
- Character counter (280/280)
- Placeholder: "Add a note about why you're sharing this..."
- Grayed out "Optional" label

**In Inbox:**
- Show sender's message below track info
- "Reply" button (if haven't replied yet)
- Reply interface: same 280-char limit
- After reply sent: button changes to "Replied ✓"

**In Crate:**
- Tap song to see conversation thread
- Shows both messages (if exist)
- Visual indicator if conversation exists (speech bubble icon)

#### Why These Limits?

**Philosophy:**
- Music is the message - words are context
- Prevents feature creep into full messaging
- Maintains intentionality of each share
- Reduces moderation burden
- Differentiates from Instagram DMs / iMessage

**What We're Avoiding:**
- ❌ Read receipts
- ❌ Typing indicators
- ❌ Message reactions/emojis (besides the music itself)
- ❌ Message editing/deleting (keep it authentic)
- ❌ Voice messages
- ❌ Image attachments
- ❌ Link sharing (music links only)

#### Technical Implementation

```javascript
// Enforce message limits
async function sendMessage(shareId, userId, messageText, messageType) {
  // Check character limit
  if (messageText.length > 280) {
    throw new Error('Message too long. Keep it under 280 characters.')
  }

  // Check conversation limits
  const existingMessages = await db.messages
    .where('share_id', shareId)
    .count()

  if (existingMessages >= 2) {
    throw new Error('Conversation limit reached. Only one message per person.')
  }

  // Check if user already sent a message for this share
  const userMessage = await db.messages
    .where('share_id', shareId)
    .where('sender_id', userId)
    .first()

  if (userMessage) {
    throw new Error('You've already sent a message for this song.')
  }

  // Create message
  return await db.messages.create({
    share_id: shareId,
    sender_id: userId,
    recipient_id: getRecipientId(shareId),
    message_text: messageText,
    message_type: messageType,
    timestamp: new Date()
  })
}
```

#### Notification Integration

**When reply is sent:**
- Trigger real-time notification (see Section 2.2)
- "[Name] replied to your message"
- Opens to conversation thread view

**NOT included in daily digest:**
- Replies are high-value, immediate notifications only

#### Moderation Considerations

**Content Policy:**
- No hate speech
- No spam
- No external links (except music platform links)
- No solicitation

**Enforcement:**
- Report button on each message
- Manual review for reported messages
- Strike system (3 strikes = messaging disabled)
- Automated filter for common spam patterns

**Scaling:**
```javascript
// Basic spam detection
function isSpam(messageText) {
  const spamPatterns = [
    /bit\.ly/i,
    /click here/i,
    /buy now/i,
    /follow me/i
  ]
  return spamPatterns.some(pattern => pattern.test(messageText))
}
```

#### Success Metrics

- 40%+ of shares include a message from sender
- 30%+ of shared songs get a reply
- <1% of messages reported as spam/abuse
- Average message length: 80-120 characters
- Qualitative: Users describe conversations as "meaningful" not "chatty"

**Key Question to Validate:**
- Do limited conversations enhance the experience or feel frustrating?
- A/B test: conversations enabled vs. disabled for cohorts

---

### Phase 2 Success Criteria
- [ ] 5,000 active users
- [ ] 60% week-4 retention
- [ ] Average 5 sends per user per week (up from 3)
- [ ] 70%+ notification engagement
- [ ] Qualitative: Users report satisfaction from seeing impact

---

## Phase 3: Phlocks - The Killer Feature (Months 5-7)

**Goal:** Build the viral, shareable visualization that defines Phlock
**Key Question:** *Do users screenshot and share their phlocks?*

### 3.1 Basic Phlock Visualization (v1)

**What It Is:** An interactive network graph showing how a song spread through your network

**Start Simple - MVP Design:**
```
        YOU
         |
    ┌────┴────┐
  Alex      Sarah
    |         |
  Mike     Jordan
           Kayla
```

**Technical Stack Options:**
- react-native-svg for custom rendering
- D3.js with react-native-svg bindings
- Victory Native for charts
- OR consider web view with D3 for v1 (faster iteration)

**MVP Features:**
- [ ] Show your direct sends (1st generation)
- [ ] Show who they forwarded to (2nd generation)
- [ ] Maybe 3rd generation (if exists)
- [ ] Tap node to see person's name
- [ ] Show timestamps on edges
- [ ] Highlight paths (e.g., "You → Alex → Mike")

**Visual Design:**
- **Nodes:** Circles with profile photos
  - Size: Larger = forwarded to more people
  - Color: Green = saved to Crate, Gray = only played
- **Edges:** Lines between nodes
  - Thickness: Time to forward (thick = shared quickly)
  - Animation: Pulse when new forwards happen
- **Layout:** Tree/hierarchical (you at root)

**Database Schema:**
```sql
phlocks {
  id: uuid (primary key)
  origin_share_id: uuid (the first share that started it)
  song_utid: string
  created_by: uuid (user who initiated)
  created_at: timestamp
  total_reach: integer (calculated)
  max_depth: integer (calculated)
  last_updated: timestamp
}

phlock_nodes {
  id: uuid (primary key)
  phlock_id: uuid (foreign key)
  share_id: uuid (foreign key → shares)
  depth: integer (generation: 0=you, 1=direct, 2=2nd gen)
  parent_node_id: uuid (foreign key → self)
}
```

**Rendering Performance:**
- Lazy load for large phlocks (>50 nodes)
- Pre-calculate layouts on backend
- Cache visualization as image after first render
- Consider native module if performance issues

---

### 3.2 Phlock Metrics

**Display Above Visualization:**
- "This phlock reached **12 people**"
- "Spreading **3 generations** deep"
- "**5 people** saved it to their Crate"
- "Started **[X days]** ago"

**Detailed Stats:**
- Conversion rate: "42% saved" (clickable for explanation)
- Viral coefficient: "Each person shared with 1.2 others"
- Geographic spread: "3 cities" (if we track location)
- Top amplifiers: "[Name] shared with 4 people"

---

### 3.3 Share Your Phlock

**Critical for Viral Growth:**

**Features:**
- [ ] "Share Phlock" button
- [ ] Generate static image (screenshot of visualization)
- [ ] Generate animated GIF (if possible, showing growth)
- [ ] Social share text template
- [ ] Deep link back to app

**Share Template:**
```
My phlock for "[Song Title] - [Artist]" reached [X] people! 🎵

[Visualization Image]

Join Phlock to see how your music taste spreads: [link]
```

**Share Destinations:**
- Instagram Stories (with branded frame)
- Twitter/X
- Messages (iMessage/SMS)
- Copy link

**Technical Implementation:**
- Use react-native-view-shot to capture visualization
- Upload to CDN for sharing
- Create deep link with phlock_id parameter
- Track shares → new user signups

**Success Metrics:**
- **20%+ of users share at least one phlock** to social media
- Average 3 shares per active user per month
- Phlock shares → new user conversion >10%

---

### 3.4 Phlock Gallery

**Your Personal Collection of Influence:**

**Features:**
- [ ] "Your Phlocks" tab in profile
- [ ] Grid view of all your phlocks
- [ ] Sort by: Reach, Recent, Viral Depth, Saves
- [ ] Filter by: Artist, Time period
- [ ] Search your phlocks
- [ ] Stats across all phlocks

**Gallery Stats:**
- "You've created **47 phlocks**"
- "Total reach: **342 people**"
- "Most viral: [Song] → 28 people"
- "Best conversion: [Song] → 86% saved"

**Why This Matters:**
- Makes users feel like collectors of influence
- Showcases their identity as tastemakers
- Creates desire to "fill the gallery" (gamification without competition)

---

### Phase 3 Success Criteria
- [ ] 20,000 active users
- [ ] 20%+ share phlocks to social media
- [ ] K-factor approaching 1.0 (viral growth)
- [ ] Average 5-10 phlocks per active user
- [ ] Qualitative: Phlocks become the signature feature people talk about

---

## Phase 4: Proof-of-Influence System (Months 7-9)

**Goal:** Build scoring infrastructure that makes Phlock valuable to artists
**Key Question:** *Do artists care about this data?*

### 4.1 Implement Full Scoring Algorithm

**Per Artist, Per User:**

```
Influence Score = (Reach × 1.0) + (Conversion × 2.0) + (Virality × 3.0)

Where:
- Reach = # unique recipients in past 30 days
- Conversion = % who saved or forwarded
- Virality = # of 2nd+ generation shares
```

**Why These Weights:**
- Reach (1.0) = Important but easy to game
- Conversion (2.0) = Proves quality, harder to fake
- Virality (3.0) = Highest value, shows true influence

**Database Schema:**
```sql
influence_scores {
  id: uuid (primary key)
  user_id: uuid (foreign key → users)
  artist_id: string (Spotify/Apple artist ID)
  artist_name: string

  -- Raw metrics (30-day rolling window)
  reach: integer
  total_shares: integer
  saves_count: integer
  forwards_count: integer

  -- Calculated metrics
  conversion_rate: decimal
  virality_count: integer
  score: decimal

  -- Window
  window_start: date
  window_end: date
  calculated_at: timestamp
}
```

**Calculation Logic:**
```javascript
async function calculateInfluenceScore(userId, artistId) {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)

  // Get all shares for this artist by this user
  const shares = await db.shares
    .where('sender_id', userId)
    .where('artist_id', artistId)
    .where('timestamp', '>', thirtyDaysAgo)
    .with('engagements')

  const reach = new Set(shares.map(s => s.recipient_id)).size
  const totalShares = shares.length

  const saves = shares.filter(s =>
    s.engagements.some(e => e.action === 'saved')
  ).length

  const forwards = shares.filter(s =>
    s.engagements.some(e => e.action === 'forwarded')
  ).length

  const conversionRate = (saves + forwards) / totalShares

  // Count 2nd+ generation shares
  const viralityCount = await countViralShares(shares)

  const score = (reach * 1.0) + (conversionRate * 100 * 2.0) + (viralityCount * 3.0)

  return {
    reach,
    totalShares,
    savesCount: saves,
    forwardsCount: forwards,
    conversionRate,
    viralityCount,
    score
  }
}
```

**Update Strategy:**
- [ ] Run nightly job to recalculate all scores
- [ ] Update on-demand when user requests their stats
- [ ] Keep 30-day rolling window (delete old data)
- [ ] Archive historical scores monthly for trends

---

### 4.2 User-Facing Influence Dashboard

**Location:** Profile → "Your Influence" tab

**Show Top Artists:**
```
🎵 You're a Top Curator For:

1. Khruangbin - Score: 142
   └ Reached 23 people | 73% saved | 8 viral shares

2. Unknown Mortal Orchestra - Score: 89
   └ Reached 15 people | 67% saved | 4 viral shares

3. Japanese Breakfast - Score: 67
   └ Reached 12 people | 58% saved | 2 viral shares
```

**Per-Artist Breakdown (tap to expand):**
- "You introduced **15 people** to [Artist]"
- "Your conversion rate: **73%** (very high!)"
- "Your phlocks reached **3 cities**"
- "You're in the **top 5%** of [Artist] curators"

**Achievements/Milestones:**
- "First Discovery" badge (shared before they hit 100k listeners)
- "Superfan" (top 1% for an artist)
- "Taste Maker" (high conversion across artists)
- "Network Effect" (created 5+ viral phlocks)

**Success Metrics:**
- Users check influence dashboard 2+ times per week
- Users share screenshots of their top artists
- Correlation between high scores and continued engagement

---

### 4.3 Basic Artist Intelligence

**Before Building Full Dashboard, Validate with Manual Exports:**

**Process:**
- [ ] Artists request data via email/form on website
- [ ] Manually verify artist identity (Spotify for Artists, social proof)
- [ ] Export CSV with:
  - Top 50 advocates (user_id anonymized)
  - Influence scores
  - Geographic distribution (city level)
  - Phlock stats for their songs
- [ ] Optional: Send phlock visualizations as PDFs

**Data Format:**
```csv
advocate_id,influence_score,reach,conversion_rate,city,state,top_song_shared
user_1234,142,23,73%,Brooklyn,NY,"Song Title"
user_5678,89,15,67%,Los Angeles,CA,"Song Title"
...
```

**Feedback Loop:**
- Schedule follow-up calls with first 20 artists
- Ask: "How did you use this data?"
- Learn: What questions do they have?
- Iterate: What features would make this actionable?

**Success Metrics:**
- 5+ artists actively use the data
- Artists report specific actions taken (tour planning, fan outreach)
- Artists willing to pay for deeper access

---

### Phase 4 Success Criteria
- [ ] 50,000 active users
- [ ] Influence scores calculated for 10,000+ artists
- [ ] 20+ artists using data exports
- [ ] Qualitative: Artists describe data as "eye-opening" and "actionable"

---

## Phase 5: Artist Dashboard (Months 9-12)

**Goal:** Build the B2B product that generates revenue
**Key Question:** *Will artists pay for this?*

### 5.1 Artist Portal

**Authentication:**
- [ ] Verify via Spotify for Artists / Apple Music for Artists
- [ ] Manual verification for independent artists (social proof)
- [ ] Link artist profiles across platforms

**Dashboard Structure:**

#### Tab 1: Overview
```
🎵 [Artist Name] - Phlock Dashboard

Total Reach: 3,247 people
Active Advocates: 89
Phlocks Created: 234
Avg Conversion: 58%

[Chart: Reach over time]
[Map: Geographic distribution]
```

#### Tab 2: Songs
```
Your Top Songs by Phlock Reach:

1. "Song Title A"
   • 47 phlocks | 892 people reached | 67% saved
   • [View Phlocks] [Activate Fans]

2. "Song Title B"
   • 34 phlocks | 673 people reached | 54% saved
   • [View Phlocks] [Activate Fans]
```

#### Tab 3: Advocates
```
Your Top Advocates:

1. @username (opted in to be visible)
   • Influence Score: 142
   • Reached 23 people
   • Based in: Brooklyn, NY
   • [Send Message]

2. Anonymous User
   • Influence Score: 89
   • Reached 15 people
   • Based in: Los Angeles, CA
   • [Send Reward Offer]
```

**Privacy Settings:**
- Default: Advocates are anonymized
- Users can opt-in to be visible to artists they promote
- Geographic data shown at city level only
- Message sending requires user opt-in

#### Tab 4: Insights
```
🎯 Tour Recommendations:
Based on your advocate concentration:
- Brooklyn, NY (23 advocates)
- Los Angeles, CA (18 advocates)
- Austin, TX (12 advocates)

📈 Trending Songs:
Songs with rising phlocks this week:
- "Song Title C" (+12 phlocks)
- "Song Title A" (+8 phlocks)

🔍 Discovery Potential:
New advocates this month: 34
Average advocate influence: 67
```

---

### 5.2 Artist Activation Tools

**Message Top Advocates:**
- [ ] Send direct message to opted-in advocates
- [ ] Limit: 1 message per advocate per month (anti-spam)
- [ ] Message templates for common use cases
- [ ] Track open rates and responses

**Create Exclusive Offers:**
- [ ] Early access to new releases
- [ ] Discount codes for merch
- [ ] Pre-sale ticket access
- [ ] Meet & greet opportunities
- [ ] Exclusive content (demos, behind-the-scenes)

**Offer Distribution:**
```javascript
// Artist creates offer
const offer = {
  type: 'presale_tickets',
  title: '24h Presale Access',
  description: 'Thanks for spreading the word!',
  code: 'PHLOCK2025',
  expires: '2025-11-01',
  targetAudience: 'top_50_advocates' // or 'city:brooklyn', 'score:>100'
}

// System notifies eligible users
// Tracks redemptions
// Artist pays 10% transaction fee to Phlock
```

**ROI Tracking:**
- Show artist how many advocates redeemed
- Track downstream impact (did rewarded advocates share more?)
- Calculate $ value generated per advocate

---

### 5.3 Pricing Tiers

#### Free Tier
- Basic stats for your **top song**
- See aggregated advocate count (but not individual advocates)
- View 1 sample phlock visualization
- Limit: 1 message per month to all advocates (broadcast only)

#### Pro Tier - $29/month (for emerging artists)
- Full analytics for **all songs**
- Top 50 advocates visible (with opt-in)
- Geographic insights (city level)
- Unlimited messaging to opted-in advocates
- Create exclusive offers (10% platform fee)
- Export data as CSV
- Priority support

#### Label/Enterprise - $299/month
- Multi-artist management dashboard
- Up to 10 artist profiles
- Advanced analytics and trends
- API access for custom integrations
- Bulk messaging tools
- Custom reporting
- White-glove onboarding
- Dedicated account manager

**Add-ons:**
- Extra artist profiles: $20/month each
- Additional messages: $10 per 100 messages
- Custom integrations: Quote-based

**Payment Processing:**
- Stripe for subscriptions
- Annual discount: 2 months free (encourage commitment)
- 14-day free trial for Pro tier
- Money-back guarantee (30 days)

---

### Phase 5 Success Criteria
- [ ] 100,000 active users
- [ ] 100+ artists on paid plans
- [ ] $3,000+ MRR (Monthly Recurring Revenue)
- [ ] <5% churn rate for paid artists
- [ ] Net Promoter Score (NPS) >50 from artist users

---

## Phase 6: Growth & Optimization (Months 12-18)

**Goal:** Optimize viral mechanics and scale the network

### 6.1 Viral Growth Mechanics

**Share-to-Non-Member Flow:**

Current: User tries to send to non-member → Error

Optimized:
```
User selects non-member friend
  ↓
"[Friend] isn't on Phlock yet. Send them an invite?"
  ↓
[Send Invite] button
  ↓
SMS/Email: "woon sent you a song! 🎵"
+ 30-second preview link
+ "[Song] by [Artist]"
+ "Sign up for Phlock to hear the full track and send songs back"
+ [Sign Up] button
  ↓
Non-member clicks, experiences music
  ↓
Sign up flow (optimized for mobile)
  ↓
Immediately see the full song they were invited for
  ↓
Prompt to send a song back to woon
```

**K-Factor Calculation:**
```
K = (invites sent per user) × (conversion rate) × (invites from new user)

Target: K > 1.0 for exponential growth

Example:
- Average user invites 3 non-members
- 33% conversion rate
- New users invite 2 people in first week
- K = 3 × 0.33 × 2 = 1.98 (excellent!)
```

**Optimization Tactics:**
- [ ] A/B test invite copy (personal vs. functional)
- [ ] Optimize preview experience (make it compelling)
- [ ] Reduce signup friction (1-tap social auth)
- [ ] Incentivize new user activation (send 1st song within 5 min)
- [ ] Track drop-off points in invite-to-signup funnel

---

### 6.2 Retention Mechanisms

**Weekly Digest Email:**
```
Subject: Your Phlocks Are Growing 🎵

Hi woon,

Your musical influence this week:

📊 Your songs reached 18 people (+5 from last week)
🔥 3 people saved your recommendations
🎯 Your phlock for "Song Title" grew to 12 people!

[View Your Phlocks]

New songs from friends:
• Alex sent: "Song A" by Artist
• Jordan sent: "Song B" by Artist

[See All]
```

**Push Notification Strategy:**

**High-Priority (immediate):**
- New song from friend
- Your song was saved (high-value action)
- Your song went viral (5+ forwards)

**Medium-Priority (batched):**
- Friend listened to your song (batch: "3 friends listened today")
- Weekly stats summary

**Low-Priority (weekly digest only):**
- Friend joined Phlock
- Milestones (10th phlock created, 100 people reached)

**Re-engagement Campaigns:**
- Day 3: "You haven't sent a song to [Name] yet"
- Day 7: "Your friends sent you 3 songs this week"
- Day 14: "Remember when you discovered [Artist]?"
- Day 30: "Your musical influence is growing"

---

### 6.3 Gamification (Light Touch)

**Annual Wrap-Up (Phlock Wrapped):**
```
Your 2025 in Music

🎵 You shared 187 songs
📊 Your music reached 342 people
🏆 Top Artist Influence: Khruangbin (Score: 142)
🔥 Most Viral Phlock: "Song Title" → 28 people
🎯 Your Conversion Rate: 64% (top 10%!)
📍 Your music spread to 12 cities
👥 5 friends discovered new favorites through you

[Share Your Year]
```

**Badges (Non-Competitive):**
- 🔍 **Early Adopter**: Shared artist before they hit 100k listeners
- 🎯 **Tastemaker**: 70%+ conversion rate
- 🌊 **Viral Curator**: Created 5+ phlocks with 3+ generations
- 🌍 **City Connector**: Your phlocks reached 5+ cities
- 💎 **Deep Cuts**: Shared 50+ tracks with <1M plays
- 🎨 **Genre Explorer**: Shared across 10+ genres

**What to AVOID:**
- ❌ Public leaderboards (creates toxicity)
- ❌ Competitive scoring between users
- ❌ "You're rank #347!" messages
- ❌ Forced sharing to unlock features
- ❌ Pay-to-win mechanics

**Success Metrics:**
- 70% week-8 retention
- Average session length: 3+ minutes
- Monthly active users / Total users: >40%

---

### 6.4 Platform Partnerships

**Approach Streaming Platforms:**

**Value Proposition to Spotify/Apple Music:**
- "We drive users back to your app more frequently"
- "We increase listening engagement"
- "We convert free users to premium (Phlock requires authenticated accounts)"
- "We make your platform stickier (switching would mean losing social graph)"

**Partnership Tiers:**

**Tier 1: API Partnership (no revenue share)**
- Formal API access agreement
- Higher rate limits
- Featured in "Partner Apps" section
- Co-marketing opportunities

**Tier 2: Revenue Share**
- Share affiliate revenue when Phlock drives premium conversions
- 50/50 split on incremental premium subscriptions
- Joint marketing campaigns

**Tier 3: White-Label Integration**
- Phlock functionality built into Spotify/Apple Music
- Licensing fee: $X per user per year
- Fully branded as platform feature
- Phlock becomes infrastructure

**Partnership Milestones:**
- [ ] 100K users: Reach out for initial conversations
- [ ] 500K users: Formal partnership discussions
- [ ] 1M users: Revenue-sharing agreement
- [ ] 5M users: Acquisition discussions (if desired)

---

### Phase 6 Success Criteria
- [ ] 200,000 active users
- [ ] K-factor >1.0 (sustained viral growth)
- [ ] 70%+ week-8 retention
- [ ] API partnership with at least 1 major platform
- [ ] $10,000+ MRR

---

## Phase 7: Monetization & Scale (Months 18-24)

**Goal:** Build sustainable business with positive unit economics

### 7.1 Premium User Subscriptions

#### Free Tier
- 1 send per friend per day
- Basic phlock visualizations (static)
- Standard profile
- Ads in email digests (non-intrusive)

#### Premium - $4.99/month
- **3 sends per friend per day**
- Advanced phlock visualizations (animated, interactive)
- Extended history (all-time stats vs. 30-day)
- Priority notifications
- Custom themes
- No ads
- Early access to features
- Exclusive badges

**Premium Features to Test:**
- Unlimited Crate storage vs. 100 songs for free
- Save phlocks as videos for social sharing
- Advanced filters in friend picker
- Voice notes on shares (30-second message)
- Schedule sends for later

**Pricing Strategy:**
- Launch at $4.99 to test willingness to pay
- Consider annual: $49.99/year (2 months free)
- Student discount: $2.99/month
- Family plan: $9.99/month for 5 users

**Conversion Tactics:**
- Free trial: 14 days premium for new users
- Upgrade prompts when hitting send limit
- Show premium users' advanced phlocks to free users
- "Your friend is Premium" social proof

**Success Metrics:**
- 5-10% free-to-premium conversion
- <3% monthly churn for premium
- LTV:CAC ratio >3:1

---

### 7.2 Artist Revenue Streams

**Transaction Fees:**
```
Artist creates offer (presale tickets, merch discount)
  ↓
Distributes through Phlock
  ↓
Advocate redeems
  ↓
Purchase happens on artist's site
  ↓
Phlock takes 10% of transaction value
```

**Examples:**
- $30 presale ticket → Phlock gets $3
- $50 merch purchase with 20% discount → Phlock gets $4
- $100 meet & greet → Phlock gets $10

**Affiliate Revenue:**
- **Ticketing:** Partner with Dice, Bandsintown, Eventbrite
  - User clicks through to buy tickets
  - Phlock gets 5-10% affiliate cut

- **Merch:** Partner with Merchbar, Bandcamp
  - User clicks through to buy merch
  - Phlock gets 10-15% affiliate cut

- **Streaming:** Spotify/Apple Music Premium signups
  - User converts to premium after receiving share
  - Phlock gets $5-10 per conversion

**Revenue Projections:**
```
With 500K users:
- 100K premium users × $4.99 = $499K/month
- 500 paid artists × $50 avg = $25K/month
- Transaction fees: ~$10K/month
- Affiliates: ~$20K/month
Total: ~$554K/month = $6.6M/year
```

---

### 7.3 Label & A&R Tools (Enterprise)

**Product:** Early signal system for emerging artists

**Value Proposition:**
- Identify artists gaining organic traction before mainstream
- See which artists have strong word-of-mouth
- Track geographic concentration of fanbases
- Discover talent before competitors

**Features:**
- [ ] Search/browse all artists on platform
- [ ] Filter by: Phlock growth rate, geographic concentration, genre
- [ ] Alert system: "Artists with 50%+ phlock growth this month"
- [ ] Compare artists side-by-side
- [ ] Export prospect lists
- [ ] Track artists over time
- [ ] Integration with Spotify for Artists API

**Dashboard View:**
```
🔍 Trending Artists - Last 30 Days

1. Artist Name
   • +127% phlock growth
   • 47 active advocates
   • Strong in: Brooklyn, Portland, Austin
   • Avg influence score: 78
   • [View Details] [Add to Watchlist]

2. Artist Name
   • +89% phlock growth
   ...
```

**Pricing:**
- **A&R Pro:** $500/month
  - 1 user
  - Track up to 100 artists
  - Weekly trend reports

- **Label Enterprise:** $2,000/month
  - 5 users
  - Unlimited artist tracking
  - API access
  - Custom reports
  - Dedicated support

**Success Metrics:**
- 10+ labels/A&R teams paying
- Labels discover and sign artists found through Phlock
- Case studies of successful discoveries

---

### Phase 7 Success Criteria
- [ ] 500,000+ active users
- [ ] $500K+ MRR
- [ ] Positive unit economics (profitable per user)
- [ ] Validated business model across B2C and B2B
- [ ] Multiple revenue streams diversified

---

## Technical Architecture Evolution

### Current Stack (musiclinkr)
```
Frontend: React Native + Expo
APIs: Spotify, Apple Music, YouTube, SoundCloud, etc.
Track Resolution: Custom UTID system + Songlink fallback
Deployment: Expo managed workflow
```

### Phase 1-3 Additions
```
Authentication: Firebase Auth or Supabase
Database: Supabase (PostgreSQL) or Firebase Firestore
Notifications: Expo Notifications + Firebase Cloud Messaging
Storage: Cloudflare R2 or AWS S3 (for images)
CDN: Cloudflare (for phlock visualizations)
Analytics: Mixpanel or Amplitude
Crash Reporting: Sentry
```

### Phase 4-7 Additions
```
Background Jobs: Inngest or Trigger.dev
Scoring Engine: Dedicated service (Node.js + Redis)
Real-time: Supabase Realtime or Pusher
Search: Algolia or Meilisearch (for artist discovery)
Payments: Stripe
Email: Resend or SendGrid
Admin Dashboard: Retool or custom React app
```

### Data Architecture
```
Users
  ↓ has many
Shares (sender_id, recipient_id)
  ↓ has many
Engagements (played, saved, forwarded)
  ↓ aggregates into
Influence Scores (per user, per artist)
  ↓ generates
Phlocks (visualization data)
```

---

## Migration Path from musiclinkr

### What to Keep
- ✅ All API integration code (services/*)
- ✅ Track resolution logic
- ✅ Cross-platform mapping
- ✅ UTID system
- ✅ UI component library
- ✅ React Native + Expo setup

### What to Transform
- 🔄 Convert screen → Becomes "Send to Friend" flow
- 🔄 Search → Becomes track picker in send flow
- 🔄 Home screen → Becomes inbox/feed

### What to Add
- ➕ Authentication system
- ➕ Database layer
- ➕ Social graph infrastructure
- ➕ Notification system
- ➕ Visualization engine
- ➕ Scoring system
- ➕ Artist portal (separate web app)

### Code Organization
```
phlock/
├── src/
│   ├── services/
│   │   ├── track-resolver.js (WAS: music-converter.js)
│   │   ├── spotify-api.js (KEEP)
│   │   ├── apple-music-api.js (KEEP)
│   │   ├── auth.js (NEW)
│   │   ├── shares.js (NEW)
│   │   ├── influence.js (NEW)
│   │   └── notifications.js (NEW)
│   ├── screens/
│   │   ├── InboxScreen.js (NEW - was HomeScreen)
│   │   ├── SendScreen.js (NEW)
│   │   ├── CrateScreen.js (NEW)
│   │   ├── PhlocksScreen.js (NEW)
│   │   ├── ProfileScreen.js (NEW)
│   │   └── StatsScreen.js (NEW)
│   ├── components/
│   │   ├── PlatformSelector.js (KEEP)
│   │   ├── TrackCard.js (ENHANCE)
│   │   ├── PhlockVisualization.js (NEW)
│   │   ├── FriendPicker.js (NEW)
│   │   ├── InboxCard.js (NEW)
│   │   └── CrateItem.js (NEW)
│   └── utils/
│       ├── db.js (NEW - database client)
│       ├── phlock-calculator.js (NEW)
│       └── score-calculator.js (NEW)
├── functions/ (NEW - backend/serverless)
│   ├── calculate-scores.js
│   ├── generate-phlocks.js
│   └── send-notifications.js
└── artist-portal/ (NEW - separate web app)
    └── (Next.js or similar)
```

---

## Success Metrics by Phase

### Phase 1 (Social MVP)
- ✅ 1,000 active users
- ✅ 50% week-2 retention
- ✅ 3+ sends per user per week
- ✅ 40%+ save-to-Crate rate

### Phase 2 (Feedback Loops)
- ✅ 5,000 active users
- ✅ 60% week-4 retention
- ✅ 5+ sends per user per week
- ✅ 70%+ notification open rate

### Phase 3 (Phlocks)
- ✅ 20,000 active users
- ✅ 20%+ share phlocks externally
- ✅ K-factor approaching 1.0

### Phase 4 (Proof-of-Influence)
- ✅ 50,000 active users
- ✅ 20+ artists using data

### Phase 5 (Artist Dashboard)
- ✅ 100,000 active users
- ✅ 100+ paid artists
- ✅ $3K MRR

### Phase 6 (Growth)
- ✅ 200,000 active users
- ✅ K-factor >1.0
- ✅ 70%+ week-8 retention

### Phase 7 (Scale)
- ✅ 500,000+ active users
- ✅ $500K+ MRR
- ✅ Profitable unit economics

---

## Critical Risks & Mitigations

### Behavioral Risks

**Risk 1: Users Won't Share with Limits**
- Hypothesis: Daily limits increase perceived value
- Test Early: A/B test with/without limits in Phase 1
- Mitigation: Start with 3 sends/day, dial down if engagement is high

**Risk 2: Phlocks Aren't Compelling**
- Hypothesis: Visual feedback drives sharing
- Test Early: Build MVP visualization in Phase 3, measure shares
- Mitigation: Iterate on design, consider hiring visualization specialist

**Risk 3: Artists Don't Value the Data**
- Hypothesis: Influence data is actionable for artists
- Test Early: Manual exports in Phase 4, qualitative feedback
- Mitigation: Pivot to pure consumer play if artist value unclear

### Technical Risks

**Risk 1: API Rate Limits**
- Impact: Can't resolve tracks fast enough
- Mitigation: Aggressive caching, use Songlink API as fallback, rate limit user requests

**Risk 2: Phlock Visualization Performance**
- Impact: Laggy UI kills the feature
- Mitigation: Pre-calculate layouts on backend, cache as images, consider native module

**Risk 3: Notification Delivery at Scale**
- Impact: Missed notifications = broken feedback loop
- Mitigation: Use reliable service (FCM), implement retry logic, monitor delivery rates

### Business Risks

**Risk 1: Platform API Access Revoked**
- Impact: Existential threat
- Mitigation: Support 5+ platforms for redundancy, build partnerships early, demonstrate mutual value

**Risk 2: Cold Start Problem**
- Impact: Network effects require critical mass
- Mitigation: Seed with music communities, college campuses, genre-specific influencers

**Risk 3: Competition from Incumbents**
- Impact: Spotify/Apple build similar features
- Mitigation: Cross-platform is our moat, move fast, build community lock-in

---

## Go-to-Market Strategy

### Phase 1-2: Private Beta
- Target: Music-obsessed early adopters
- Channels:
  - Personal network
  - Music subreddits (r/indieheads, r/listentothis)
  - College campuses (partner with student groups)
- Goal: 1,000 highly engaged users

### Phase 3: Public Beta
- Target: Tastemakers and music curators
- Channels:
  - Product Hunt launch
  - Twitter/X music community
  - Music blogs/press (Pitchfork, Stereogum)
  - TikTok (phlock visualizations as content)
- Goal: 20,000 users, viral coefficient >0.7

### Phase 4-5: Artist Acquisition
- Target: Independent artists and small labels
- Channels:
  - Direct outreach to artists with growing phlocks
  - Music industry conferences (SXSW, CMJ)
  - Partnerships with distribution platforms (DistroKid, TuneCore)
- Goal: 100 paid artists

### Phase 6-7: Mainstream Growth
- Target: General music listeners
- Channels:
  - Paid ads (Instagram, TikTok) once LTV validated
  - App Store optimization
  - Influencer partnerships
  - PR push (TechCrunch, Verge, Wired)
- Goal: 500K+ users, household name in music tech

---

## When to Pivot or Persist

### Green Lights (Keep Going)
- ✅ Week-2 retention >50%
- ✅ Users sharing 3+ times per week
- ✅ Phlocks being shared to social media organically
- ✅ Artists actively requesting data
- ✅ Word-of-mouth growth (K-factor >0.5)

### Yellow Lights (Iterate)
- ⚠️ Retention declining after Phase 1
  - → Test different constraints, feedback loops
- ⚠️ Low phlock sharing
  - → Redesign visualizations, make more compelling
- ⚠️ Artists don't value data
  - → Deeper interviews, find the real need

### Red Lights (Consider Pivot)
- 🚫 Week-2 retention <30%
  - → Fundamental product-market fit issue
- 🚫 Users not sharing despite no limits
  - → Behavior change too hard, need different hook
- 🚫 Can't get artists to pay
  - → Pure consumer play only
- 🚫 API access revoked by major platform
  - → Technical moat broken

---

## Next Steps

### Immediate (This Week)
- [ ] Set up development environment for Phase 1
- [ ] Choose database (recommend: Supabase)
- [ ] Design database schema for users + shares
- [ ] Sketch UI mockups for send flow

### This Month
- [ ] Implement authentication
- [ ] Build friend management
- [ ] Create send transaction flow
- [ ] Deploy alpha version

### This Quarter
- [ ] Complete Phase 1
- [ ] Private beta with 50 users
- [ ] Iterate based on feedback
- [ ] Plan Phase 2

---

## Key Decisions to Make

### Technical
- [ ] Database: Supabase vs. Firebase vs. self-hosted Postgres?
- [ ] Auth: Firebase Auth vs. Supabase Auth vs. Clerk?
- [ ] Visualization: D3 + SVG vs. Canvas vs. WebView vs. Native?
- [ ] Deployment: Stay on Expo managed workflow vs. bare workflow?

### Product
- [ ] Daily send limit: 1 vs. 2 vs. 3 per friend?
- [ ] Phlock visibility: Public vs. friends-only vs. opt-in?
- [ ] Artist verification: Automatic vs. manual vs. hybrid?
- [ ] Monetization: Freemium vs. artist-only vs. both?

### Business
- [ ] Legal structure: LLC vs. C-corp?
- [ ] Fundraising: Bootstrap vs. angel vs. VC?
- [ ] Team: Solo vs. co-founder vs. early hires?
- [ ] Timeline: Fast launch vs. polished product?

---

## Resources & References

### Competitors & Inspiration
- **Airbuds** - Passive cross-platform sharing via widgets
- **Stationhead** - Superfan engagement platform
- **Last.fm** - OG social music tracking
- **Spotify Friend Activity** - Failed attempt at social features
- **SongShift** - Playlist conversion tool

### Technical Resources
- React Native + Expo docs
- Spotify Web API
- Apple Music API
- Supabase docs
- D3.js for visualizations

### Books & Articles
- "Hooked" by Nir Eyal (behavioral design)
- "The Long Tail" by Chris Anderson (discovery economics)
- "The Lean Startup" by Eric Ries (validation methodology)

---

**Last Updated:** October 15, 2025
**Version:** 1.2
**Next Review:** End of Phase 1

---

## Document Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-15 | 1.2 | Added: In-app preview playback (1.5) using Spotify and Apple Music preview URLs |
| 2025-10-15 | 1.1 | Added: Native library detection (2.4), hybrid notification strategy (2.2), conversation features (2.5), enhanced Crate positioning (1.3), save-to-forward marked as optional |
| 2025-10-14 | 1.0 | Initial roadmap created |

---

_This is a living document. Update as we learn, pivot, and progress._
