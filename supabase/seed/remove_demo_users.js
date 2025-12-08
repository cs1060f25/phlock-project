// Remove demo users: Alex, Brittany, Cam, Daniel, Emily
// Run with: node supabase/seed/remove_demo_users.js

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://szfxnzsapojuemltjghb.supabase.co';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseServiceKey) {
  console.error('Error: SUPABASE_SERVICE_ROLE_KEY environment variable is required');
  console.error('Run with: SUPABASE_SERVICE_ROLE_KEY=your_key node supabase/seed/remove_demo_users.js');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

const demoUserIds = [
  'a1111111-1111-1111-1111-111111111111', // Alex
  'b2222222-2222-2222-2222-222222222222', // Brittany
  'c3333333-3333-3333-3333-333333333333', // Cam
  'd4444444-4444-4444-4444-444444444444', // Daniel
  'e5555555-5555-5555-5555-555555555555', // Emily
];

async function removeDemoUsers() {
  console.log('Removing demo users: Alex, Brittany, Cam, Daniel, Emily...\n');

  // Delete from tables in order (respecting foreign keys)
  const tables = [
    { name: 'notifications', columns: ['user_id', 'actor_id'] },
    { name: 'follows', columns: ['follower_id', 'following_id'] },
    { name: 'phlock_history', columns: ['user_id', 'phlock_member_id'] },
    { name: 'scheduled_swaps', columns: ['user_id', 'new_member_id', 'old_member_id'] },
    { name: 'scheduled_removals', columns: ['user_id', 'member_id'] },
    { name: 'share_comments', columns: ['user_id'] },
    { name: 'engagements', columns: ['user_id'] },
    { name: 'phlock_nodes', columns: ['user_id'] },
    { name: 'phlocks', columns: ['created_by'] },
    { name: 'shares', columns: ['sender_id', 'recipient_id'] },
    { name: 'friendships', columns: ['user_id', 'friend_id'] },
    { name: 'platform_tokens', columns: ['user_id'] },
    { name: 'device_tokens', columns: ['user_id'] },
    { name: 'user_contacts', columns: ['user_id'] },
    { name: 'users', columns: ['id'] },
  ];

  for (const table of tables) {
    try {
      for (const column of table.columns) {
        const { error, count } = await supabase
          .from(table.name)
          .delete({ count: 'exact' })
          .in(column, demoUserIds);

        if (error) {
          // Table might not exist, that's okay
          if (!error.message.includes('does not exist')) {
            console.log(`  ⚠️  ${table.name}.${column}: ${error.message}`);
          }
        } else if (count > 0) {
          console.log(`  ✓ Deleted ${count} rows from ${table.name} (${column})`);
        }
      }
    } catch (err) {
      console.log(`  ⚠️  ${table.name}: ${err.message}`);
    }
  }

  // Verify deletion
  console.log('\nVerifying deletion...');
  const { data: remaining, error: verifyError } = await supabase
    .from('users')
    .select('id, username, display_name')
    .in('username', ['alex', 'brittany', 'cam', 'daniel', 'emily']);

  if (verifyError) {
    console.error('Verification error:', verifyError.message);
  } else if (remaining && remaining.length > 0) {
    console.log('⚠️  Some users still remain:', remaining);
  } else {
    console.log('✓ All demo users successfully removed!');
  }
}

removeDemoUsers().catch(console.error);
