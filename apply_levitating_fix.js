/**
 * Fix Album Artwork for "Levitating" Track
 *
 * This script updates the database to fix the incorrect track ID and album artwork
 * for "Levitating" by Dua Lipa. The seed data had the wrong Spotify track ID, which
 * pointed to a different track with Doja Cat's "Planet Her" album art.
 *
 * Correct track:
 *   - Track ID: 5nujrmhLynf4yMoMtj8AQF
 *   - Track Name: Levitating (feat. DaBaby)
 *   - Album Art: https://i.scdn.co/image/ab67616d00001e022172b607853fa89cefa2beb4
 *
 * Usage:
 *   1. Set your service role key:
 *      export SUPABASE_SERVICE_ROLE_KEY=<your-key>
 *   2. Run the script:
 *      node apply_levitating_fix.js
 */
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = "https://szfxnzsapojuemltjghb.supabase.co";
// Using service role key to bypass RLS for admin operations
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.error('❌ SUPABASE_SERVICE_ROLE_KEY environment variable not set');
  console.log('\nTo fix this:');
  console.log('  1. Get your service role key from: https://supabase.com/dashboard/project/szfxnzsapojuemltjghb/settings/api');
  console.log('  2. Run: export SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>');
  console.log('  3. Run this script again: node apply_levitating_fix.js\n');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function applyFix() {
  console.log('🔧 Applying Levitating track fix to database...\n');

  // First, check current state
  console.log('📊 Current state:');
  const { data: currentShares, error: fetchError } = await supabase
    .from('shares')
    .select('id, track_id, track_name, artist_name, album_art_url')
    .ilike('track_name', '%levitating%');

  if (fetchError) {
    console.error('❌ Error fetching current data:', fetchError);
    return;
  }

  if (!currentShares || currentShares.length === 0) {
    console.log('No Levitating shares found');
    return;
  }

  console.log(`Found ${currentShares.length} shares:`);
  for (const share of currentShares) {
    console.log(`  - "${share.track_name}" (ID: ${share.track_id})`);
    console.log(`    Album art: ${share.album_art_url}`);
  }

  // Apply the fix
  console.log('\n🔄 Applying fix...');
  const { data, error } = await supabase
    .from('shares')
    .update({
      track_id: '5nujrmhLynf4yMoMtj8AQF',
      track_name: 'Levitating (feat. DaBaby)',
      album_art_url: 'https://i.scdn.co/image/ab67616d00001e022172b607853fa89cefa2beb4'
    })
    .ilike('track_name', '%levitating%')
    .eq('artist_name', 'Dua Lipa')
    .select();

  if (error) {
    console.error('❌ Error applying fix:', error);
    return;
  }

  console.log(`✅ Fixed ${data.length} shares`);

  // Verify the fix
  console.log('\n✅ Verification:');
  const { data: updatedShares } = await supabase
    .from('shares')
    .select('id, track_id, track_name, artist_name, album_art_url')
    .ilike('track_name', '%levitating%');

  if (updatedShares) {
    for (const share of updatedShares) {
      console.log(`  - "${share.track_name}" (ID: ${share.track_id})`);
      console.log(`    Album art: ${share.album_art_url}`);
    }
  }

  console.log('\n🎉 Fix applied successfully!');
}

applyFix().catch(console.error);
