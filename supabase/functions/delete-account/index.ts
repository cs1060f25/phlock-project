import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get the authorization header to identify the user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create a Supabase client with the user's JWT to get their ID
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    // User client to get the authenticated user
    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: userError } = await userClient.auth.getUser();

    if (userError || !user) {
      console.error('Failed to get user:', userError);
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userId = user.id;
    console.log(`🗑️ Deleting account for user: ${userId}`);

    // Create admin client to delete data and auth user
    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // First, get the user's ID from the users table (different from auth user ID)
    const { data: userRecord, error: userLookupError } = await adminClient
      .from('users')
      .select('id')
      .eq('auth_user_id', userId)
      .single();

    if (userLookupError) {
      console.error('Error finding user record:', userLookupError);
      // User might not have a users table record, continue with auth deletion
    }

    const publicUserId = userRecord?.id;
    console.log(`📋 Public user ID: ${publicUserId}, Auth user ID: ${userId}`);

    // Delete user data from public tables in the correct order (foreign key constraints)
    // Order matters: delete dependent records first
    // Note: We use publicUserId for tables that reference users.id, and userId for auth.users references

    if (publicUserId) {
      // 1. Delete notifications (where user is actor or recipient)
      const { error: notifError } = await adminClient
        .from('notifications')
        .delete()
        .or(`user_id.eq.${publicUserId},actor_id.eq.${publicUserId}`);
      if (notifError) console.error('Error deleting notifications:', notifError);

      // 2. Delete shares
      const { error: sharesError } = await adminClient
        .from('shares')
        .delete()
        .eq('user_id', publicUserId);
      if (sharesError) console.error('Error deleting shares:', sharesError);

      // 3. Delete friendships (where user is either party)
      const { error: friendshipsError } = await adminClient
        .from('friendships')
        .delete()
        .or(`user_id.eq.${publicUserId},friend_id.eq.${publicUserId}`);
      if (friendshipsError) console.error('Error deleting friendships:', friendshipsError);

      // 4. Delete friend requests (where user is either sender or receiver)
      const { error: requestsError } = await adminClient
        .from('friend_requests')
        .delete()
        .or(`from_user_id.eq.${publicUserId},to_user_id.eq.${publicUserId}`);
      if (requestsError) console.error('Error deleting friend requests:', requestsError);

      // 5. Delete device tokens
      const { error: tokensError } = await adminClient
        .from('device_tokens')
        .delete()
        .eq('user_id', publicUserId);
      if (tokensError) console.error('Error deleting device tokens:', tokensError);

      // 6. Delete platform tokens (OAuth tokens for Spotify/Apple Music)
      const { error: platformTokensError } = await adminClient
        .from('platform_tokens')
        .delete()
        .eq('user_id', publicUserId);
      if (platformTokensError) console.error('Error deleting platform tokens:', platformTokensError);

      // 7. Delete scheduled swaps
      const { error: scheduledSwapsError } = await adminClient
        .from('scheduled_swaps')
        .delete()
        .eq('user_id', publicUserId);
      if (scheduledSwapsError) console.error('Error deleting scheduled swaps:', scheduledSwapsError);

      // 8. Delete user profile from users table
      // Note: This might cascade automatically due to auth_user_id FK, but explicit delete is safer
      const { error: userProfileError } = await adminClient
        .from('users')
        .delete()
        .eq('id', publicUserId);
      if (userProfileError) console.error('Error deleting user profile:', userProfileError);
    }

    // 9. Finally, delete from auth.users (requires service role)
    const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(userId);
    if (authDeleteError) {
      console.error('Error deleting auth user:', authDeleteError);
      return new Response(
        JSON.stringify({ error: 'Failed to delete authentication record' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`✅ Successfully deleted account for user: ${userId}`);

    return new Response(
      JSON.stringify({ success: true, message: 'Account deleted successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error in delete-account function:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
