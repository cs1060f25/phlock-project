// Fix demo shares - upsert daily songs for demo users
// Run with: SUPABASE_SERVICE_ROLE_KEY=your_key node supabase/seed/fix_demo_shares.js

const SUPABASE_URL = 'https://szfxnzsapojuemltjghb.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY environment variable is required');
  console.log('Get it from: https://supabase.com/dashboard/project/szfxnzsapojuemltjghb/settings/api');
  process.exit(1);
}

const today = new Date().toISOString().split('T')[0];
console.log(`Today's date: ${today}\n`);

// Demo user IDs
const demoUsers = {
  alex: 'a1111111-1111-1111-1111-111111111111',
  brittany: 'b2222222-2222-2222-2222-222222222222',
  cam: 'c3333333-3333-3333-3333-333333333333',
  daniel: 'd4444444-4444-4444-4444-444444444444',
  emily: 'e5555555-5555-5555-5555-555555555555'
};

// Daily songs for each demo user
const shares = [
  {
    id: 'f1111111-1111-1111-1111-111111111111',
    sender_id: demoUsers.alex,
    recipient_id: demoUsers.alex,
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
    sender_id: demoUsers.brittany,
    recipient_id: demoUsers.brittany,
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
    sender_id: demoUsers.cam,
    recipient_id: demoUsers.cam,
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
    sender_id: demoUsers.daniel,
    recipient_id: demoUsers.daniel,
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
    sender_id: demoUsers.emily,
    recipient_id: demoUsers.emily,
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

async function run() {
  // Step 1: Check if demo users exist
  console.log('Step 1: Checking demo users...');
  const usersResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/users?id=in.(${Object.values(demoUsers).join(',')})&select=id,display_name,username`,
    {
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      }
    }
  );
  const users = await usersResponse.json();
  console.log(`Found ${users.length} demo users:`, users.map(u => `@${u.username}`).join(', '));

  // Step 2: Delete existing daily songs for demo users today
  console.log('\nStep 2: Deleting existing daily songs for today...');
  const deleteResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/shares?sender_id=in.(${Object.values(demoUsers).join(',')})&is_daily_song=eq.true&selected_date=eq.${today}`,
    {
      method: 'DELETE',
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      }
    }
  );
  console.log('Delete response:', deleteResponse.status);

  // Step 3: Insert new shares
  console.log('\nStep 3: Inserting daily songs...');
  const insertResponse = await fetch(`${SUPABASE_URL}/rest/v1/shares`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify(shares)
  });

  if (!insertResponse.ok) {
    const error = await insertResponse.text();
    console.error('Failed to insert shares:', error);
    return;
  }

  const inserted = await insertResponse.json();
  console.log(`Inserted ${inserted.length} daily songs`);

  // Step 4: Verify the shares exist
  console.log('\nStep 4: Verifying shares...');
  const verifyResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/shares?is_daily_song=eq.true&selected_date=eq.${today}&sender_id=in.(${Object.values(demoUsers).join(',')})&select=sender_id,track_name,artist_name,selected_date`,
    {
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      }
    }
  );
  const verified = await verifyResponse.json();
  console.log('Verified shares:', JSON.stringify(verified, null, 2));

  // Step 5: Check woon's phlock membership
  console.log('\nStep 5: Checking @woon\'s phlock...');
  const woonResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/users?username=eq.woon&select=id`,
    {
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      }
    }
  );
  const woonData = await woonResponse.json();

  if (woonData.length === 0) {
    console.log('User @woon not found');
    return;
  }

  const woonId = woonData[0].id;
  console.log(`Found @woon with ID: ${woonId}`);

  // Check who @woon follows and has in phlock
  const phlockResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/follows?follower_id=eq.${woonId}&is_in_phlock=eq.true&select=following_id,phlock_position`,
    {
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      }
    }
  );
  const phlockMembers = await phlockResponse.json();
  console.log(`@woon's phlock members (${phlockMembers.length}):`, JSON.stringify(phlockMembers, null, 2));

  // Check if demo users are in the phlock
  const demoUserIds = new Set(Object.values(demoUsers));
  const demoInPhlock = phlockMembers.filter(m => demoUserIds.has(m.following_id));
  console.log(`\nDemo users in @woon's phlock: ${demoInPhlock.length}`);

  if (demoInPhlock.length === 0) {
    console.log('\n⚠️  No demo users are in @woon\'s phlock!');
    console.log('To add them: Go to each demo user\'s profile and tap "Add to Phlock"');
  } else {
    console.log('\n✅ Demo setup complete! Refresh the Phlock view to see the songs.');
  }
}

run().catch(console.error);
