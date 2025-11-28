const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://szfxnzsapojuemltjghb.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6ZnhuenNhcG9qdWVtbHRqZ2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNTQ0NjcsImV4cCI6MjA3NjgzMDQ2N30.DcKveqZzSWTVWQGy8SbQR0XDxwinYhcSDV7CH4C2itc';

const supabase = createClient(supabaseUrl, supabaseKey);

async function check() {
    // Find test2 user
    const { data: users, error: userError } = await supabase
        .from('users')
        .select('*')
        .ilike('display_name', '%test2%');

    if (userError) {
        console.error('Error fetching users:', userError);
        return;
    }

    console.log('=== Users matching "test2" ===');
    users.forEach(u => {
        console.log('  ' + u.display_name + ' (' + u.id + ')');
        console.log('    phlock_count: ' + u.phlock_count);
        console.log('    reach_count: ' + u.reach_count);
    });

    if (users.length === 0) {
        console.log('No users found matching test2');
        return;
    }

    const test2 = users[0];
    console.log('\n=== Checking phlock data for ' + test2.display_name + ' ===');

    // Check who has test2 in their phlock (current)
    const { data: whoHasMe, error: phlockError } = await supabase
        .from('follows')
        .select('*, follower:follower_id(display_name)')
        .eq('following_id', test2.id)
        .eq('is_in_phlock', true);

    if (phlockError) {
        console.error('Error:', phlockError);
    } else {
        console.log('\nCurrent phlock memberships (who has test2 in their phlock):');
        console.log('  Count: ' + whoHasMe.length);
        whoHasMe.forEach(f => {
            const name = f.follower ? f.follower.display_name : f.follower_id;
            console.log('  - ' + name + ' (position ' + f.phlock_position + ')');
        });
    }

    // Check phlock_history for test2
    const { data: history, error: historyError } = await supabase
        .from('phlock_history')
        .select('*, owner:phlock_owner_id(display_name)')
        .eq('phlock_member_id', test2.id);

    if (historyError) {
        console.error('Error fetching history:', historyError);
    } else {
        console.log('\nHistorical phlock reach (all-time):');
        console.log('  Count: ' + history.length);
        history.forEach(h => {
            const name = h.owner ? h.owner.display_name : h.phlock_owner_id;
            console.log('  - Added by ' + name + ' at ' + h.first_added_at);
        });
    }

    // Also find test1 to verify relationship
    const { data: test1Users } = await supabase
        .from('users')
        .select('*')
        .ilike('display_name', '%test1%');

    if (test1Users && test1Users.length > 0) {
        const test1 = test1Users[0];
        console.log('\n=== test1 user ===');
        console.log('  ' + test1.display_name + ' (' + test1.id + ')');

        // Check test1's phlock members
        const { data: test1Phlock } = await supabase
            .from('follows')
            .select('*, following:following_id(display_name)')
            .eq('follower_id', test1.id)
            .eq('is_in_phlock', true);

        console.log('\ntest1\'s phlock members:');
        if (test1Phlock) {
            test1Phlock.forEach(f => {
                const name = f.following ? f.following.display_name : f.following_id;
                console.log('  - ' + name + ' (position ' + f.phlock_position + ')');
            });
        }
    }
}

async function checkAll() {
    console.log('\n=== ALL FOLLOWS ===');
    const { data: allFollows, error: followsErr } = await supabase
        .from('follows')
        .select('*');

    if (followsErr) {
        console.error('Error:', followsErr);
    } else {
        console.log('Total follows: ' + allFollows.length);
        allFollows.forEach(f => {
            console.log('  follower=' + f.follower_id + ' -> following=' + f.following_id + ' is_in_phlock=' + f.is_in_phlock + ' pos=' + f.phlock_position);
        });
    }

    console.log('\n=== ALL PHLOCK_HISTORY ===');
    const { data: allHistory, error: histErr } = await supabase
        .from('phlock_history')
        .select('*');

    if (histErr) {
        console.error('Error:', histErr);
    } else {
        console.log('Total history records: ' + allHistory.length);
        allHistory.forEach(h => {
            console.log('  owner=' + h.phlock_owner_id + ' member=' + h.phlock_member_id);
        });
    }

    console.log('\n=== ALL USERS ===');
    const { data: allUsers, error: usersErr } = await supabase
        .from('users')
        .select('id, display_name, phlock_count, reach_count');

    if (usersErr) {
        console.error('Error:', usersErr);
    } else {
        allUsers.forEach(u => {
            console.log('  ' + u.display_name + ' (' + u.id + ')');
            console.log('    phlock_count=' + u.phlock_count + ', reach_count=' + u.reach_count);
        });
    }
}

async function checkFriendships() {
    console.log('\n=== FRIENDSHIPS TABLE ===');
    const { data: friendships, error: err } = await supabase
        .from('friendships')
        .select('*');

    if (err) {
        console.error('Error (table may not exist):', err.message);
    } else {
        console.log('Total friendships: ' + friendships.length);
        friendships.forEach(f => {
            console.log('  user1=' + f.user_id_1 + ' user2=' + f.user_id_2 + ' status=' + f.status);
        });
    }
}

async function createTestFollowAndPhlock() {
    // Get test1 and test2 IDs
    const test1Id = 'f70703fe-756f-4c3d-a4cf-53944c5a813c';
    const test2Id = 'cb612cb3-c426-495e-836c-4de48a1b1a07';

    console.log('\n=== CREATING TEST FOLLOW ===');
    console.log('test1 will follow test2 and add to phlock...');

    // Create follow relationship with phlock
    const { data: follow, error: followErr } = await supabase
        .from('follows')
        .insert({
            follower_id: test1Id,
            following_id: test2Id,
            is_in_phlock: true,
            phlock_position: 1,
            phlock_added_at: new Date().toISOString()
        })
        .select()
        .single();

    if (followErr) {
        console.error('Error creating follow:', followErr);
        return;
    }
    console.log('Follow created:', follow.id);

    // Verify the follow was created
    const { data: verifyFollow } = await supabase
        .from('follows')
        .select('*')
        .eq('follower_id', test1Id)
        .eq('following_id', test2Id)
        .single();

    console.log('Verified follow:', verifyFollow);

    // Check phlock_history (should be auto-created by trigger)
    const { data: history } = await supabase
        .from('phlock_history')
        .select('*')
        .eq('phlock_owner_id', test1Id)
        .eq('phlock_member_id', test2Id);

    console.log('Phlock history records:', history ? history.length : 0);

    // Check updated user stats
    const { data: updatedTest2 } = await supabase
        .from('users')
        .select('phlock_count, reach_count')
        .eq('id', test2Id)
        .single();

    console.log('test2 updated stats:', updatedTest2);
}

check()
    .then(() => checkAll())
    .then(() => checkFriendships())
    .then(() => createTestFollowAndPhlock())
    .then(() => {
        console.log('\n=== AFTER CREATING FOLLOW ===');
        return checkAll();
    })
    .catch(console.error);
