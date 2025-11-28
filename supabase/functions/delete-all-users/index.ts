import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Get all users from the users table
    const { data: users, error: fetchError } = await adminClient
      .from('users')
      .select('id, auth_user_id, display_name');

    if (fetchError) {
      console.error('Error fetching users:', fetchError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch users', details: fetchError }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userCount = users ? users.length : 0;
    console.log(`Found ${userCount} users to delete`);

    const results: Array<{ id?: string; authId?: string; name?: string; email?: string; deleted: boolean; orphaned?: boolean }> = [];

    for (const user of users ?? []) {
      console.log(`Deleting user: ${user.display_name} (${user.id})`);

      const publicUserId = user.id;
      const authUserId = user.auth_user_id;

      // Delete from all related tables
      await adminClient.from('notifications').delete().or(`user_id.eq.${publicUserId},actor_id.eq.${publicUserId}`);
      await adminClient.from('shares').delete().eq('user_id', publicUserId);
      await adminClient.from('friendships').delete().or(`user_id.eq.${publicUserId},friend_id.eq.${publicUserId}`);
      await adminClient.from('friend_requests').delete().or(`from_user_id.eq.${publicUserId},to_user_id.eq.${publicUserId}`);
      await adminClient.from('device_tokens').delete().eq('user_id', publicUserId);
      await adminClient.from('platform_tokens').delete().eq('user_id', publicUserId);
      await adminClient.from('scheduled_swaps').delete().eq('user_id', publicUserId);

      // Delete user profile
      await adminClient.from('users').delete().eq('id', publicUserId);

      // Delete auth user if exists
      if (authUserId) {
        const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(authUserId);
        if (authDeleteError) {
          console.error(`Failed to delete auth user ${authUserId}:`, authDeleteError);
        }
      }

      results.push({ id: publicUserId, name: user.display_name, deleted: true });
    }

    // Also clean up any orphaned auth users (auth users without a users table record)
    const { data: authUsers, error: authFetchError } = await adminClient.auth.admin.listUsers();

    if (!authFetchError && authUsers?.users) {
      for (const authUser of authUsers.users) {
        // Check if this auth user has a users table record
        const { data: existingUser } = await adminClient
          .from('users')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .single();

        if (!existingUser) {
          console.log(`Deleting orphaned auth user: ${authUser.email} (${authUser.id})`);
          await adminClient.auth.admin.deleteUser(authUser.id);
          results.push({ authId: authUser.id, email: authUser.email, deleted: true, orphaned: true });
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, deleted: results.length, users: results }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
