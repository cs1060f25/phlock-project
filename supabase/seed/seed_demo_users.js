// Seed demo phlock users for testing layout alternatives
// Run with: node supabase/seed/seed_demo_users.js

const SUPABASE_URL = 'https://szfxnzsapojuemltjghb.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY environment variable is required');
  console.log('Get it from: https://supabase.com/dashboard/project/szfxnzsapojuemltjghb/settings/api');
  console.log('Then run: SUPABASE_SERVICE_ROLE_KEY=your_key node supabase/seed/seed_demo_users.js');
  process.exit(1);
}

const users = [
  {
    id: 'a1111111-1111-1111-1111-111111111111',
    display_name: 'Alex',
    username: 'alex',
    platform_type: 'spotify',
    daily_song_streak: 5,
    phlock_count: 3
  },
  {
    id: 'b2222222-2222-2222-2222-222222222222',
    display_name: 'Brittany',
    username: 'brittany',
    platform_type: 'spotify',
    daily_song_streak: 21,
    phlock_count: 7
  },
  {
    id: 'c3333333-3333-3333-3333-333333333333',
    display_name: 'Cam',
    username: 'cam',
    platform_type: 'spotify',
    daily_song_streak: 3,
    phlock_count: 2
  },
  {
    id: 'd4444444-4444-4444-4444-444444444444',
    display_name: 'Daniel',
    username: 'daniel',
    platform_type: 'spotify',
    daily_song_streak: 8,
    phlock_count: 5
  },
  {
    id: 'e5555555-5555-5555-5555-555555555555',
    display_name: 'Emily',
    username: 'emily',
    platform_type: 'spotify',
    daily_song_streak: 12,
    phlock_count: 10
  }
];

const today = new Date().toISOString().split('T')[0];

// For daily songs, sender_id = recipient_id (self-share pattern)
const shares = [
  {
    id: 'f1111111-1111-1111-1111-111111111111',
    sender_id: 'a1111111-1111-1111-1111-111111111111',
    recipient_id: 'a1111111-1111-1111-1111-111111111111',
    track_id: '3GZD6HmiNUhxXYf8Gch723',
    track_name: 'Lost',
    artist_name: 'Frank Ocean',
    album_art_url: 'https://i.scdn.co/image/ab67616d0000b2737aede4855f6d0d738012e2e5',
    preview_url: null,
    is_daily_song: true,
    selected_date: today,
    message: 'this song never gets old',
    status: 'sent'
  },
  {
    id: 'f2222222-2222-2222-2222-222222222222',
    sender_id: 'b2222222-2222-2222-2222-222222222222',
    recipient_id: 'b2222222-2222-2222-2222-222222222222',
    track_id: '2qSkIjg1o9h3YT9RAgYN75',
    track_name: 'Espresso',
    artist_name: 'Sabrina Carpenter',
    album_art_url: 'https://i.scdn.co/image/ab67616d0000b273659cd4673230913b3918e0d5',
    preview_url: null,
    is_daily_song: true,
    selected_date: today,
    message: 'summer vibes',
    status: 'sent'
  },
  {
    id: 'f3333333-3333-3333-3333-333333333333',
    sender_id: 'c3333333-3333-3333-3333-333333333333',
    recipient_id: 'c3333333-3333-3333-3333-333333333333',
    track_id: '1oHNvJVbFkexQc0BpQp7Y4',
    track_name: 'Starships',
    artist_name: 'Nicki Minaj',
    album_art_url: 'https://i.scdn.co/image/ab67616d0000b27385235715597dcd07bb9e0f84',
    preview_url: null,
    is_daily_song: true,
    selected_date: today,
    message: null,
    status: 'sent'
  },
  {
    id: 'f4444444-4444-4444-4444-444444444444',
    sender_id: 'd4444444-4444-4444-4444-444444444444',
    recipient_id: 'd4444444-4444-4444-4444-444444444444',
    track_id: '0JXXNGljqupsJaZsgSbMZV',
    track_name: 'Sure Thing',
    artist_name: 'Miguel',
    album_art_url: 'https://i.scdn.co/image/ab67616d0000b273d5a8395b0d80b8c48a5d851c',
    preview_url: null,
    is_daily_song: true,
    selected_date: today,
    message: 'classic',
    status: 'sent'
  },
  {
    id: 'f5555555-5555-5555-5555-555555555555',
    sender_id: 'e5555555-5555-5555-5555-555555555555',
    recipient_id: 'e5555555-5555-5555-5555-555555555555',
    track_id: '7vgTNTaEz3CsBZ1N4YQalM',
    track_name: 'Good Days',
    artist_name: 'SZA',
    album_art_url: 'https://i.scdn.co/image/ab67616d0000b27304257b29be46a894e651a1a3',
    preview_url: null,
    is_daily_song: true,
    selected_date: today,
    message: 'good days only',
    status: 'sent'
  }
];

async function seedData() {
  console.log('Seeding demo users and their daily songs...\n');

  // Upsert users
  console.log('Creating users...');
  const usersResponse = await fetch(`${SUPABASE_URL}/rest/v1/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Prefer': 'resolution=merge-duplicates'
    },
    body: JSON.stringify(users)
  });

  if (!usersResponse.ok) {
    const error = await usersResponse.text();
    console.error('Failed to create users:', error);
  } else {
    console.log('✅ Created/updated 5 users');
  }

  // Upsert shares
  console.log('\nCreating daily songs...');
  const sharesResponse = await fetch(`${SUPABASE_URL}/rest/v1/shares`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Prefer': 'resolution=merge-duplicates'
    },
    body: JSON.stringify(shares)
  });

  if (!sharesResponse.ok) {
    const error = await sharesResponse.text();
    console.error('Failed to create shares:', error);
  } else {
    console.log('✅ Created/updated 5 daily songs');
  }

  console.log('\n📋 Demo users created:');
  users.forEach(u => {
    console.log(`   @${u.username} (${u.display_name}) - streak: ${u.daily_song_streak}`);
  });

  console.log('\n🎵 Daily songs:');
  shares.forEach(s => {
    console.log(`   "${s.track_name}" by ${s.artist_name}`);
  });

  console.log('\n✅ Done! Now follow these users and add them to your phlock in the app.');
}

seedData().catch(console.error);
