// Edge Function: send-push-notification
// Sends push notifications to iOS devices via APNs

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// APNs configuration
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.phlock.app";
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY") ?? "";

// Supabase configuration
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface PushPayload {
  user_id: string;
  title: string;
  body: string;
  type?: string;
  data?: Record<string, unknown>;
  badge?: number;
}

interface DeviceToken {
  id: string;
  user_id: string;
  device_token: string;
  platform: string;
  is_sandbox: boolean;
}

// Generate JWT for APNs authentication
async function generateApnsJWT(): Promise<string> {
  const header = {
    alg: "ES256",
    kid: APNS_KEY_ID,
  };

  const claims = {
    iss: APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  };

  // Import the private key
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = APNS_PRIVATE_KEY
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // Create JWT
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const encodedClaims = btoa(JSON.stringify(claims)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const signatureInput = `${encodedHeader}.${encodedClaims}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: { name: "SHA-256" } },
    key,
    new TextEncoder().encode(signatureInput)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${signatureInput}.${encodedSignature}`;
}

// Send notification to a single device
async function sendToDevice(
  token: DeviceToken,
  payload: PushPayload,
  jwt: string
): Promise<{ success: boolean; error?: string }> {
  const apnsHost = token.is_sandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";

  const apnsPayload = {
    aps: {
      alert: {
        title: payload.title,
        body: payload.body,
      },
      sound: "default",
      badge: payload.badge ?? 1,
    },
    type: payload.type,
    ...payload.data,
  };

  try {
    const response = await fetch(
      `https://${apnsHost}/3/device/${token.device_token}`,
      {
        method: "POST",
        headers: {
          "authorization": `bearer ${jwt}`,
          "apns-topic": APNS_BUNDLE_ID,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body: JSON.stringify(apnsPayload),
      }
    );

    if (response.ok) {
      return { success: true };
    } else {
      const errorBody = await response.text();
      console.error(`APNs error for device ${token.device_token}: ${response.status} - ${errorBody}`);

      // If token is invalid, we should remove it
      if (response.status === 400 || response.status === 410) {
        return { success: false, error: `invalid_token: ${errorBody}` };
      }

      return { success: false, error: `apns_error: ${response.status}` };
    }
  } catch (error) {
    console.error(`Failed to send to device ${token.device_token}:`, error);
    return { success: false, error: String(error) };
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload: PushPayload = await req.json();

    if (!payload.user_id || !payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: user_id, title, body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Check if APNs is configured
    if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
      console.warn("APNs not configured, skipping push notification");
      return new Response(
        JSON.stringify({
          success: true,
          message: "APNs not configured, notification not sent",
          sent: 0
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Get device tokens for the user
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("*")
      .eq("user_id", payload.user_id)
      .eq("platform", "ios");

    if (tokensError) {
      console.error("Failed to fetch device tokens:", tokensError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No device tokens found", sent: 0 }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Generate APNs JWT
    const jwt = await generateApnsJWT();

    // Send to all devices
    const results = await Promise.all(
      tokens.map((token: DeviceToken) => sendToDevice(token, payload, jwt))
    );

    // Remove invalid tokens
    const invalidTokens = tokens.filter(
      (token: DeviceToken, index: number) =>
        !results[index].success && results[index].error?.startsWith("invalid_token")
    );

    if (invalidTokens.length > 0) {
      const { error: deleteError } = await supabase
        .from("device_tokens")
        .delete()
        .in(
          "id",
          invalidTokens.map((t: DeviceToken) => t.id)
        );

      if (deleteError) {
        console.error("Failed to delete invalid tokens:", deleteError);
      } else {
        console.log(`Deleted ${invalidTokens.length} invalid tokens`);
      }
    }

    const successCount = results.filter((r) => r.success).length;

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: tokens.length,
        failed: tokens.length - successCount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Push notification error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
