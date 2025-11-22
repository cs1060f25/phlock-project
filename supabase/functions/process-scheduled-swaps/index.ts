import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  try {
    // Create a Supabase client with the Auth context of the logged in user
    const supabaseClient = createClient(
      // Supabase API URL - env var automatically populated by Supabase
      Deno.env.get('SUPABASE_URL') ?? '',
      // Supabase API ANON KEY - env var automatically populated by Supabase
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      // Create client with Auth context of the user that called the function
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Or use SERVICE_ROLE_KEY if this is a cron job that needs admin privileges
    // For cron jobs, we usually use the service role key because there is no user context
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Call the database function
    const { data, error } = await supabaseAdmin.rpc('process_scheduled_swaps')

    if (error) throw error

    return new Response(
      JSON.stringify({ success: true, processed_count: data }),
      { headers: { "Content-Type": "application/json" } },
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})
