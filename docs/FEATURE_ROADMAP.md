# Phlock Feature Roadmap (Legacy)

This is the legacy viral-sharing roadmap. The active daily curation priorities and production blockers are tracked in `CRITICAL_FEATURES_AND_IMPLEMENTATION_PLAN.md` and `claude.md`.

---

## Priority Features

### 1. Live Viral Dashboard

**Description:**
A real-time visualization system that shows how songs spread through your social network. Users can see the complete "phlock" (viral tree/graph) of a song - who discovered it, who they shared it with, and how far it propagated through the network.

**How It Works:**
- **Viral Tree Visualization:** Display a network graph showing the spread path of any song. Each node represents a user, edges represent shares, with the original sharer at the root.
- **Real-time Updates:** Live notifications when your shared song gets re-shared by someone down the chain ("Emma shared your recommendation with 3 friends!")
- **Metrics Dashboard:**
  - Total reach (how many people heard your share)
  - Depth (how many degrees of separation it traveled)
  - Engagement rate (% who saved/played vs just received)
  - Viral velocity (shares per hour/day)
- **Interactive Exploration:** Tap any node to see that person's share message, when they first heard it, and who they shared it with
- **Song Origin Stories:** See who in your network was the first to discover and share a track

**Technical Approach:**
- Database: Create `share_tree` table linking shares to parent shares
- Real-time: Supabase Realtime subscriptions for live updates
- Visualization: SwiftUI custom views or integrate a graph library (e.g., force-directed graph)
- Analytics: Recursive queries to calculate depth, breadth, and engagement metrics

**User Value:**
- Gamification: See your influence and impact
- Discovery: Find the tastemakers in your network
- Social proof: "50 people heard this because of you"
- Feedback loops: Immediate gratification when shares spread

---

### 2. Feedback Loops Showing Impact of Shares

**Description:**
A comprehensive system that shows users the tangible impact of their music sharing behavior, creating reward loops that encourage continued engagement.

**How It Works:**

#### 2.1 Share Impact Notifications
- **Immediate feedback:** "Marcus played your share within 5 minutes!"
- **Engagement milestones:** "Your share of 'Blinding Lights' has been saved by 5 friends"
- **Viral milestones:** "Your share reached 10 people!" (2nd degree), "Your share reached 25 people!" (3rd degree)
- **Time-based:** "3 friends are listening to your recommendations right now"

#### 2.2 Personal Impact Stats
- **Weekly/Monthly Reports:** Summary cards showing:
  - Total shares sent vs received
  - Play rate (% of your shares that were played)
  - Save rate (% that were saved/added to library)
  - Average response time (how quickly friends engage)
  - Your most influential share (highest reach)
  - Friends you've influenced most

#### 2.3 Taste Profile & Match Scores
- **Taste Compatibility:** Show % match with each friend based on shared listening preferences
- **Discovery Credit:** Track and display when you introduced someone to a new artist/genre
- **Influence Ranking:** Leaderboard of who influences your listening most (and vice versa)

#### 2.4 Engagement Streaks
- **Sharing streaks:** Days in a row you've shared music
- **Response streaks:** Friends who consistently engage with your shares
- **Discovery streaks:** Consecutive successful introductions to new artists

**Technical Approach:**
- Database: Add `share_analytics` table tracking engagement events
- Background jobs: Daily/weekly aggregation of stats
- Push notifications: Real-time engagement alerts
- Analytics engine: Calculate compatibility scores using collaborative filtering
- Caching: Pre-compute expensive stats (taste profiles, rankings)

**User Value:**
- Validation: See that your recommendations matter
- Social currency: Earn reputation as a tastemaker
- Motivation: Streaks and milestones encourage consistency
- Personalization: Understand which friends appreciate your taste

---

### 3. Social Reactions & Engagement Mechanics

**Description:**
Rich, expressive ways for users to react to and engage with shared music beyond simple play/save actions. Creates conversation and shared experiences around music.

**How It Works:**

#### 3.1 Timestamped Reactions
- **In-Song Reactions:** Drop emoji reactions at specific timestamps while listening (e.g., "🔥 at 1:23", "😭 at 2:45")
- **Reaction Playback:** When friends listen to the same song, they see your reactions appear at the exact moment you dropped them
- **Reaction Heatmap:** Visual timeline showing where friends reacted most intensely
- **Popular Moments:** Highlight the most-reacted-to sections of a song across your network

#### 3.2 Quick Response Actions
- **One-tap responses to shares:**
  - ❤️ Love it
  - 🔥 Fire
  - 🎯 My vibe
  - 😱 Mind blown
  - 💯 Perfect recommendation
  - 🤔 Interesting
  - 👎 Not for me
- **Animated feedback:** Sender sees reaction with animation
- **Response prompts:** "Emma loved this! Send her something similar?"

#### 3.3 Social Engagement Features
- **Comment threads:** Leave voice notes or text comments on shares
- **Re-share with commentary:** Add your take when passing along a friend's recommendation
- **Collaborative playlists:** Build shared playlists with friends
- **Music challenges:** "Send me your best [genre/mood] song"

#### 3.4 Rich Share Context
- **Mood tags:** "late night vibes", "workout energy", "sad girl hours"
- **Activity context:** "perfect for driving", "study music", "party starter"
- **Personal notes:** "This reminded me of that summer trip!"
- **Question prompts:** "Rate this 1-10", "Better than their last album?"

**Technical Approach:**
- Database: `reactions` table with timestamp, emoji, user_id, share_id
- Real-time: Supabase Realtime for live reaction sync during playback
- Audio sync: AVPlayer time observers to trigger reactions at exact moments
- UI: Custom SwiftUI animations for reaction feedback
- Voice notes: Audio recording/playback with compression

**User Value:**
- Expression: Go beyond binary like/dislike
- Connection: Feel like you're listening together
- Conversation starters: Reactions prompt discussions
- Personality: Share your authentic reactions
- FOMO: See what moments friends found epic

---

### 4. Competition Elements

**Description:**
Gamification features that create friendly competition and challenges between friends, leveraging music discovery and sharing as the competitive mechanic.

**How It Works:**

#### 4.1 Leaderboards & Rankings
- **Weekly Tastemaker:** Who sent the most-engaged-with shares this week
- **Discovery Pioneer:** Who introduced friends to the most new artists
- **Viral Champion:** Whose shares spread the furthest
- **Engagement King/Queen:** Highest average play rate on shares
- **Genre Expert:** Top sharer in specific genres (Hip-Hop Expert, Indie Curator, etc.)
- **Friend-specific 1v1:** Head-to-head stats with individual friends

#### 4.2 Challenges & Competitions
- **Weekly Challenges:**
  - "Discover Your Friends Week" - Send shares to 5+ friends
  - "Obscure Finds" - Share songs with <100k streams that friends love
  - "Genre Explorer" - Share from 5 different genres
  - "Time Machine" - Share throwback tracks (>10 years old)
- **Friend Battles:** Challenge a friend to see who can send better recommendations over a week
- **Streak Challenges:** Maintain sharing/engagement streaks
- **Bingo Cards:** "Get 3 friends to save your shares", "Introduce someone to a new artist", etc.

#### 4.3 Achievements & Badges
- **Milestone Badges:**
  - "First Share", "100 Shares Sent"
  - "Viral Hit" (share reached 50+ people)
  - "Taste Oracle" (90%+ play rate on shares)
  - "Genre Sommelier" (expert in specific genre)
  - "Early Adopter" (shared song before it hit 1M streams)
- **Seasonal Badges:** Limited-time achievements
- **Social Badges:** "Best Friend Duo" (most exchanges with one friend)

#### 4.4 Reputation & Levels
- **Phlock Score:** Overall reputation metric combining:
  - Share engagement rate
  - Discovery credits
  - Viral reach
  - Friend feedback
  - Consistency (streaks)
- **Level System:** Unlock new features/privileges as you level up
  - Level 5: Custom share themes
  - Level 10: Exclusive badges
  - Level 15: Featured on Discover page
- **Titles:** Earn titles based on behavior
  - "The Curator", "Viral Sensation", "Discovery Engine", "Genre Guru"

#### 4.5 Integration with Spotify/Apple Music Stats
- **Platform Battles:** Compare your Spotify Wrapped stats with friends throughout the year
- **Top Artist Showdowns:** Who discovered the most songs from trending artists
- **Listening Time Challenges:** Compete on listening minutes (if accessible)
- **Early Access Bragging Rights:** "I was listening to [artist] before they blew up"

**Technical Approach:**
- Database:
  - `leaderboards` table with time-windowed stats
  - `achievements` and `user_achievements` tables
  - `challenges` table with participation tracking
- Cron jobs: Daily/weekly calculation of rankings and challenge progress
- Push notifications: "You're #3 on this week's Tastemaker board!"
- Real-time updates: Live leaderboard updates during active challenges
- Analytics: Complex aggregation queries, consider materialized views
- Social: Friend-only visibility of rankings (privacy-focused competition)

**User Value:**
- Motivation: Gamification drives engagement
- Social status: Be recognized as the music expert in your group
- Fun: Low-stakes competition with friends
- Goals: Clear objectives give purpose to sharing
- Discovery: Challenges push you to explore new music
- Bragging rights: Show off your taste and influence

---

## Implementation Priority

**Phase 1 (MVP+):**
1. Basic share impact stats (play rate, response time)
2. Simple reactions (emoji responses to shares)
3. Friend leaderboards (basic rankings)

**Phase 2:**
1. Viral dashboard with tree visualization
2. Timestamped reactions during playback
3. Achievements & badges system
4. Weekly challenges

**Phase 3:**
1. Advanced analytics (taste compatibility, influence scores)
2. Collaborative features (playlists, challenges)
3. Seasonal competitions
4. Platform integration (Spotify/Apple Music stats)

---

## Technical Considerations

### Database Schema Additions
- `share_trees` - Track parent-child share relationships
- `reactions` - User reactions with timestamps
- `share_analytics` - Aggregated engagement metrics
- `achievements` & `user_achievements` - Gamification
- `challenges` & `challenge_participation` - Competition tracking
- `leaderboards` - Time-windowed rankings

### Real-time Requirements
- Supabase Realtime subscriptions for:
  - Live reaction sync during playback
  - Viral spread notifications
  - Leaderboard updates
  - Challenge progress

### Performance Optimization
- Materialized views for expensive aggregations
- Redis/caching layer for leaderboards
- Background jobs for analytics computation
- Efficient graph traversal algorithms for viral trees

### Privacy & Social Design
- Friend-only visibility by default
- Opt-in for public leaderboards
- Ability to hide certain stats
- Respectful notifications (not spammy)

---

## Success Metrics

- **Engagement:** Daily active shares, reaction rate, challenge participation
- **Retention:** Weekly return rate, streak maintenance
- **Virality:** Average share depth, re-share rate
- **Social:** Friend invites, cross-platform sharing
- **Satisfaction:** User feedback on gamification elements
