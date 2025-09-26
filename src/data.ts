export type Track = { id: string; title: string; artist: string; artwork: string }
export type Share = { id: string; fromUser: string; toUser: string; trackId: string; platformFrom: 'spotify'|'apple' }
export type CrateItem = { trackId: string; fromUser: string; addedAt: string }
export type PlugScore = { user: string; score: number }
export type PlugMetrics = { 
  user: string; 
  totalSends: number; 
  crateAdditions: number; 
  forwardShares: number; 
  uniqueRecipients: number;
}

export type SongMetrics = {
  trackId: string;
  totalShares: number;
  crateAdditions: number;
  forwardShares: number;
  uniqueSharingUsers: number;
  avgSharesPerUser: number;
}

export const tracks: Record<string, Track> = {
  t1: { id: 't1', title: 'How Many Miles', artist: 'Mk.gee', artwork: 'https://picsum.photos/seed/mkgee/200' },
  t2: { id: 't2', title: 'Paper', artist: 'Mk.gee', artwork: 'https://picsum.photos/seed/paper/200' },
  t3: { id: 't3', title: 'Many Times', artist: 'Dijon', artwork: 'https://picsum.photos/seed/dijon/200' },
  t4: { id: 't4', title: 'BTSTU', artist: 'Jai Paul', artwork: 'https://picsum.photos/seed/jai/200' },
  t5: { id: 't5', title: 'Get You', artist: 'Daniel Caesar', artwork: 'https://picsum.photos/seed/daniel/200' },
  t6: { id: 't6', title: 'Nights', artist: 'Frank Ocean', artwork: 'https://picsum.photos/seed/frank/200' },
  t7: { id: 't7', title: 'Self Control', artist: 'Frank Ocean', artwork: 'https://picsum.photos/seed/self/200' },
  t8: { id: 't8', title: 'Best Part', artist: 'Daniel Caesar', artwork: 'https://picsum.photos/seed/best/200' },
  t9: { id: 't9', title: 'Jasmine', artist: 'Jai Paul', artwork: 'https://picsum.photos/seed/jasmine/200' },
  t10: { id: 't10', title: 'The Dress', artist: 'Dijon', artwork: 'https://picsum.photos/seed/dress/200' },
  t11: { id: 't11', title: 'Pink + White', artist: 'Frank Ocean', artwork: 'https://picsum.photos/seed/pink/200' },
  t12: { id: 't12', title: 'Japanese Denim', artist: 'Daniel Caesar', artwork: 'https://picsum.photos/seed/denim/200' },
  t13: { id: 't13', title: 'He', artist: 'Jai Paul', artwork: 'https://picsum.photos/seed/he/200' },
  t14: { id: 't14', title: 'Big Mike\'s', artist: 'Dijon', artwork: 'https://picsum.photos/seed/mike/200' },
  t15: { id: 't15', title: 'Ivy', artist: 'Frank Ocean', artwork: 'https://picsum.photos/seed/ivy/200' },
  t16: { id: 't16', title: 'We Find Love', artist: 'Daniel Caesar', artwork: 'https://picsum.photos/seed/love/200' },
  t17: { id: 't17', title: 'Str8 Outta Mumbai', artist: 'Jai Paul', artwork: 'https://picsum.photos/seed/mumbai/200' },
  // MGK tracks
  t18: { id: 't18', title: 'Bloody Valentine', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk1/200' },
  t19: { id: 't19', title: 'My Ex\'s Best Friend', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk2/200' },
  t20: { id: 't20', title: 'Concert For Aliens', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk3/200' },
  t21: { id: 't21', title: 'Drunk Face', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk4/200' },
  t22: { id: 't22', title: 'Kiss Kiss', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk5/200' },
  t23: { id: 't23', title: 'Papercuts', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk6/200' },
  t24: { id: 't24', title: 'Love Race', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk7/200' },
  t25: { id: 't25', title: 'Mainstream Sellout', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk8/200' },
  t26: { id: 't26', title: 'Tickets To My Downfall', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk9/200' },
  t27: { id: 't27', title: 'Forget Me Too', artist: 'mgk', artwork: 'https://picsum.photos/seed/mgk10/200' },
}

export const demoShare: Share = {
  id: 'demo',
  fromUser: 'jordan',
  toUser: 'sarah',
  trackId: 't1',
  platformFrom: 'spotify',
}

export const initialCrate: CrateItem[] = [
  { trackId: 't3', fromUser: 'alexandra.moon', addedAt: '2024-01-15T10:30:00Z' },
  { trackId: 't4', fromUser: 'jordan.creates', addedAt: '2024-01-14T16:45:00Z' },
  { trackId: 't5', fromUser: 'maya.wanders', addedAt: '2024-01-13T20:15:00Z' },
  { trackId: 't6', fromUser: 'kai.sounds', addedAt: '2024-01-12T14:20:00Z' },
  { trackId: 't7', fromUser: 'zoe.vibes', addedAt: '2024-01-11T19:30:00Z' },
  { trackId: 't8', fromUser: 'noah.beats', addedAt: '2024-01-10T12:45:00Z' },
  { trackId: 't9', fromUser: 'luna.melodies', addedAt: '2024-01-09T17:15:00Z' },
  { trackId: 't10', fromUser: 'river.rhythms', addedAt: '2024-01-08T21:00:00Z' },
  { trackId: 't11', fromUser: 'sage.music', addedAt: '2024-01-07T15:30:00Z' },
  { trackId: 't12', fromUser: 'phoenix.tunes', addedAt: '2024-01-06T11:45:00Z' },
  { trackId: 't13', fromUser: 'blake.audio', addedAt: '2024-01-05T18:20:00Z' },
  { trackId: 't14', fromUser: 'raven.songs', addedAt: '2024-01-04T13:15:00Z' },
  { trackId: 't15', fromUser: 'storm.sound', addedAt: '2024-01-03T16:30:00Z' },
  { trackId: 't16', fromUser: 'willow.waves', addedAt: '2024-01-02T09:45:00Z' },
  { trackId: 't17', fromUser: 'ash.tracks', addedAt: '2024-01-01T22:00:00Z' },
]

export type Activity = {
  id: string
  type: 'share' | 'add' | 'play'
  user: string
  trackTitle: string
  trackArtist: string
  targetUser?: string
  timestamp: string
}

export const initialActivity: Activity[] = [
  { id: 'a1', type: 'share', user: 'alexandra.moon', trackTitle: 'Many Times', trackArtist: 'Dijon', targetUser: 'sarah', timestamp: new Date(Date.now() - 2 * 60 * 1000).toISOString() }, // 2 minutes ago
  { id: 'a2', type: 'add', user: 'jordan.creates', trackTitle: 'BTSTU', trackArtist: 'Jai Paul', timestamp: new Date(Date.now() - 8 * 60 * 1000).toISOString() }, // 8 minutes ago
  { id: 'a3', type: 'share', user: 'maya.wanders', trackTitle: 'Get You', trackArtist: 'Daniel Caesar', targetUser: 'kai.sounds', timestamp: new Date(Date.now() - 15 * 60 * 1000).toISOString() }, // 15 minutes ago
  { id: 'a4', type: 'play', user: 'noah.beats', trackTitle: 'Nights', trackArtist: 'Frank Ocean', timestamp: new Date(Date.now() - 24 * 60 * 1000).toISOString() }, // 24 minutes ago
  { id: 'a5', type: 'share', user: 'luna.melodies', trackTitle: 'Jasmine', trackArtist: 'Jai Paul', targetUser: 'river.rhythms', timestamp: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString() }, // 3 hours ago
  { id: 'a6', type: 'add', user: 'sage.music', trackTitle: 'The Dress', trackArtist: 'Dijon', timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString() }, // 5 hours ago
  { id: 'a7', type: 'share', user: 'phoenix.tunes', trackTitle: 'Pink + White', trackArtist: 'Frank Ocean', targetUser: 'blake.audio', timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() }, // yesterday
  { id: 'a8', type: 'play', user: 'raven.songs', trackTitle: 'Japanese Denim', trackArtist: 'Daniel Caesar', timestamp: new Date(Date.now() - 30 * 60 * 60 * 1000).toISOString() }, // yesterday
]
export const initialLeaderboard: PlugScore[] = [
  { user: 'alexandra.moon', score: 520 },
  { user: 'sarah', score: 380 },
  { user: 'jordan.creates', score: 330 },
  { user: 'maya.wanders', score: 295 },
  { user: 'kai.sounds', score: 267 },
  { user: 'zoe.vibes', score: 245 },
  { user: 'noah.beats', score: 223 },
  { user: 'luna.melodies', score: 201 },
  { user: 'river.rhythms', score: 189 },
  { user: 'sage.music', score: 177 },
  { user: 'phoenix.tunes', score: 165 },
  { user: 'blake.audio', score: 153 },
  { user: 'raven.songs', score: 141 },
  { user: 'storm.sound', score: 129 },
  { user: 'willow.waves', score: 117 },
  { user: 'ash.tracks', score: 105 },
  { user: 'skye.notes', score: 93 },
  { user: 'jade.harmony', score: 81 },
  { user: 'reed.mix', score: 69 },
  { user: 'brook.flow', score: 57 },
]

export const artistLeaderboards: Record<string, PlugScore[]> = {
  'mkgee': [
    { user: 'alexandra.moon', score: 520 },
    { user: 'sarah', score: 380 },
    { user: 'jordan.creates', score: 330 },
    { user: 'maya.wanders', score: 295 },
    { user: 'kai.sounds', score: 267 },
    { user: 'zoe.vibes', score: 245 },
    { user: 'noah.beats', score: 223 },
    { user: 'luna.melodies', score: 201 },
    { user: 'river.rhythms', score: 189 },
    { user: 'sage.music', score: 177 },
    { user: 'phoenix.tunes', score: 165 },
    { user: 'blake.audio', score: 153 },
    { user: 'raven.songs', score: 141 },
    { user: 'storm.sound', score: 129 },
    { user: 'willow.waves', score: 117 },
    { user: 'ash.tracks', score: 105 },
    { user: 'skye.notes', score: 93 },
    { user: 'jade.harmony', score: 81 },
    { user: 'reed.mix', score: 69 },
    { user: 'brook.flow', score: 57 },
  ],
  'dijon': [
    { user: 'maya.wanders', score: 445 },
    { user: 'alexandra.moon', score: 320 },
    { user: 'sarah', score: 298 },
    { user: 'kai.sounds', score: 267 },
    { user: 'noah.beats', score: 234 },
    { user: 'luna.melodies', score: 201 },
    { user: 'river.rhythms', score: 189 },
    { user: 'sage.music', score: 177 },
    { user: 'phoenix.tunes', score: 165 },
    { user: 'blake.audio', score: 153 },
    { user: 'raven.songs', score: 141 },
    { user: 'storm.sound', score: 129 },
    { user: 'willow.waves', score: 117 },
    { user: 'ash.tracks', score: 105 },
    { user: 'skye.notes', score: 93 },
    { user: 'jade.harmony', score: 81 },
    { user: 'reed.mix', score: 69 },
    { user: 'brook.flow', score: 57 },
  ],
  'jaipaul': [
    { user: 'jordan.creates', score: 380 },
    { user: 'sarah', score: 345 },
    { user: 'alexandra.moon', score: 298 },
    { user: 'maya.wanders', score: 267 },
    { user: 'kai.sounds', score: 234 },
    { user: 'luna.melodies', score: 201 },
    { user: 'river.rhythms', score: 189 },
    { user: 'sage.music', score: 177 },
    { user: 'phoenix.tunes', score: 165 },
    { user: 'blake.audio', score: 153 },
    { user: 'raven.songs', score: 141 },
    { user: 'storm.sound', score: 129 },
    { user: 'willow.waves', score: 117 },
    { user: 'ash.tracks', score: 105 },
    { user: 'skye.notes', score: 93 },
    { user: 'jade.harmony', score: 81 },
    { user: 'reed.mix', score: 69 },
    { user: 'brook.flow', score: 57 },
  ],
  'danielcaesar': [
    { user: 'sarah', score: 420 },
    { user: 'alexandra.moon', score: 380 },
    { user: 'maya.wanders', score: 345 },
    { user: 'jordan.creates', score: 298 },
    { user: 'kai.sounds', score: 267 },
    { user: 'noah.beats', score: 234 },
    { user: 'luna.melodies', score: 201 },
    { user: 'river.rhythms', score: 189 },
    { user: 'sage.music', score: 177 },
    { user: 'phoenix.tunes', score: 165 },
    { user: 'blake.audio', score: 153 },
    { user: 'raven.songs', score: 141 },
    { user: 'storm.sound', score: 129 },
    { user: 'willow.waves', score: 117 },
    { user: 'ash.tracks', score: 105 },
    { user: 'skye.notes', score: 93 },
    { user: 'jade.harmony', score: 81 },
    { user: 'reed.mix', score: 69 },
    { user: 'brook.flow', score: 57 },
  ],
  'frankocean': [
    { user: 'alexandra.moon', score: 480 },
    { user: 'maya.wanders', score: 365 },
    { user: 'jordan.creates', score: 320 },
    { user: 'sarah', score: 298 },
    { user: 'kai.sounds', score: 267 },
    { user: 'noah.beats', score: 234 },
    { user: 'luna.melodies', score: 201 },
    { user: 'river.rhythms', score: 189 },
    { user: 'sage.music', score: 177 },
    { user: 'phoenix.tunes', score: 165 },
    { user: 'blake.audio', score: 153 },
    { user: 'raven.songs', score: 141 },
    { user: 'storm.sound', score: 129 },
    { user: 'willow.waves', score: 117 },
    { user: 'ash.tracks', score: 105 },
    { user: 'skye.notes', score: 93 },
    { user: 'jade.harmony', score: 81 },
    { user: 'reed.mix', score: 69 },
    { user: 'brook.flow', score: 57 },
  ],
}

export const userArtists = [
  { id: 'mkgee', name: 'Mk.gee', userPosition: 2 },
  { id: 'dijon', name: 'Dijon', userPosition: 3 },
  { id: 'jaipaul', name: 'Jai Paul', userPosition: 2 },
  { id: 'danielcaesar', name: 'Daniel Caesar', userPosition: 1 },
  { id: 'frankocean', name: 'Frank Ocean', userPosition: 4 },
]

export const artistActivity: Activity[] = [
  { id: 'aa1', type: 'share', user: 'alexandra.moon', trackTitle: 'Bloody Valentine', trackArtist: 'mgk', targetUser: 'sarah', timestamp: new Date(Date.now() - 5 * 60 * 1000).toISOString() }, // 5 minutes ago
  { id: 'aa2', type: 'add', user: 'jordan.creates', trackTitle: 'My Ex\'s Best Friend', trackArtist: 'mgk', timestamp: new Date(Date.now() - 12 * 60 * 1000).toISOString() }, // 12 minutes ago
  { id: 'aa3', type: 'share', user: 'maya.wanders', trackTitle: 'Concert For Aliens', trackArtist: 'mgk', targetUser: 'kai.sounds', timestamp: new Date(Date.now() - 18 * 60 * 1000).toISOString() }, // 18 minutes ago
  { id: 'aa4', type: 'play', user: 'noah.beats', trackTitle: 'Drunk Face', trackArtist: 'mgk', timestamp: new Date(Date.now() - 25 * 60 * 1000).toISOString() }, // 25 minutes ago
  { id: 'aa5', type: 'share', user: 'luna.melodies', trackTitle: 'Kiss Kiss', trackArtist: 'mgk', targetUser: 'river.rhythms', timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString() }, // 2 hours ago
  { id: 'aa6', type: 'add', user: 'sage.music', trackTitle: 'Papercuts', trackArtist: 'mgk', timestamp: new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString() }, // 3 hours ago
  { id: 'aa7', type: 'share', user: 'phoenix.tunes', trackTitle: 'Love Race', trackArtist: 'mgk', targetUser: 'blake.audio', timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() }, // yesterday
  { id: 'aa8', type: 'play', user: 'raven.songs', trackTitle: 'Mainstream Sellout', trackArtist: 'mgk', timestamp: new Date(Date.now() - 30 * 60 * 60 * 1000).toISOString() }, // yesterday
]

export type InboxItem = { trackId: string; fromUser: string; receivedAt: string }

export const initialInbox: InboxItem[] = [
  { trackId: 't1', fromUser: 'alexandra.moon', receivedAt: new Date(Date.now() - 10 * 60 * 1000).toISOString() }, // 10 minutes ago
  { trackId: 't2', fromUser: 'jordan.creates', receivedAt: new Date(Date.now() - 45 * 60 * 1000).toISOString() }, // 45 minutes ago
  { trackId: 't3', fromUser: 'maya.wanders', receivedAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString() }, // 2 hours ago
  { trackId: 't4', fromUser: 'kai.sounds', receivedAt: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString() }, // 4 hours ago
  { trackId: 't5', fromUser: 'zoe.vibes', receivedAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString() }, // yesterday
]

export const mgkPlugMetrics: PlugMetrics[] = [
  { user: 'alexandra.moon', totalSends: 47, crateAdditions: 23, forwardShares: 8, uniqueRecipients: 31 },
  { user: 'jordan.creates', totalSends: 34, crateAdditions: 18, forwardShares: 6, uniqueRecipients: 28 },
  { user: 'maya.wanders', totalSends: 29, crateAdditions: 15, forwardShares: 4, uniqueRecipients: 24 },
  { user: 'kai.sounds', totalSends: 26, crateAdditions: 12, forwardShares: 3, uniqueRecipients: 22 },
  { user: 'zoe.vibes', totalSends: 23, crateAdditions: 11, forwardShares: 2, uniqueRecipients: 19 },
  { user: 'noah.beats', totalSends: 21, crateAdditions: 9, forwardShares: 2, uniqueRecipients: 17 },
  { user: 'luna.melodies', totalSends: 19, crateAdditions: 8, forwardShares: 1, uniqueRecipients: 15 },
  { user: 'river.rhythms', totalSends: 17, crateAdditions: 7, forwardShares: 1, uniqueRecipients: 13 },
  { user: 'sage.music', totalSends: 15, crateAdditions: 6, forwardShares: 1, uniqueRecipients: 11 },
  { user: 'phoenix.tunes', totalSends: 13, crateAdditions: 5, forwardShares: 0, uniqueRecipients: 9 },
]

export const mgkSongMetrics: SongMetrics[] = [
  { trackId: 't18', totalShares: 127, crateAdditions: 89, forwardShares: 23, uniqueSharingUsers: 45, avgSharesPerUser: 2.8 }, // Bloody Valentine
  { trackId: 't19', totalShares: 98, crateAdditions: 67, forwardShares: 18, uniqueSharingUsers: 38, avgSharesPerUser: 2.6 }, // My Ex's Best Friend
  { trackId: 't20', totalShares: 76, crateAdditions: 52, forwardShares: 14, uniqueSharingUsers: 31, avgSharesPerUser: 2.5 }, // Concert For Aliens
  { trackId: 't21', totalShares: 65, crateAdditions: 43, forwardShares: 11, uniqueSharingUsers: 28, avgSharesPerUser: 2.3 }, // Drunk Face
  { trackId: 't22', totalShares: 54, crateAdditions: 37, forwardShares: 9, uniqueSharingUsers: 24, avgSharesPerUser: 2.3 }, // Kiss Kiss
  { trackId: 't23', totalShares: 43, crateAdditions: 29, forwardShares: 7, uniqueSharingUsers: 21, avgSharesPerUser: 2.0 }, // Papercuts
  { trackId: 't24', totalShares: 38, crateAdditions: 26, forwardShares: 6, uniqueSharingUsers: 19, avgSharesPerUser: 2.0 }, // Love Race
  { trackId: 't25', totalShares: 32, crateAdditions: 22, forwardShares: 5, uniqueSharingUsers: 17, avgSharesPerUser: 1.9 }, // Mainstream Sellout
  { trackId: 't26', totalShares: 28, crateAdditions: 19, forwardShares: 4, uniqueSharingUsers: 15, avgSharesPerUser: 1.9 }, // Tickets To My Downfall
  { trackId: 't27', totalShares: 24, crateAdditions: 16, forwardShares: 3, uniqueSharingUsers: 13, avgSharesPerUser: 1.8 }, // Forget Me Too
]
