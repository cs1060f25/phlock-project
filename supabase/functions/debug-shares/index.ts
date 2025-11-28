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

    // Parse request body for action
    let action = 'list';
    let deleteId: string | null = null;
    try {
      const body = await req.json();
      action = body.action || 'list';
      deleteId = body.deleteId || null;
    } catch {
      // No body or invalid JSON, default to list
    }

    if (action === 'delete' && deleteId) {
      // Delete a specific share
      const { error: deleteError } = await adminClient
        .from('shares')
        .delete()
        .eq('id', deleteId);

      if (deleteError) {
        return new Response(
          JSON.stringify({ error: 'Failed to delete share', details: deleteError }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, deleted: deleteId }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get all shares
    const { data: shares, error: sharesError } = await adminClient
      .from('shares')
      .select('id, track_name, artist_name, selected_date, is_daily_song, sender_id, created_at')
      .order('created_at', { ascending: false })
      .limit(20);

    if (sharesError) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch shares', details: sharesError }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ shares, count: shares?.length ?? 0 }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
