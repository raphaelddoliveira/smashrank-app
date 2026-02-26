// Supabase Edge Function: send-push-notification
// Triggered by Database Webhook on INSERT into notifications table.
// Sends a Firebase Cloud Messaging push via FCM v1 API (OAuth2).

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  create,
  getNumericDate,
} from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Firebase service account credentials (set via supabase secrets)
const FCM_CLIENT_EMAIL = Deno.env.get("FCM_CLIENT_EMAIL")!;
const FCM_PRIVATE_KEY = Deno.env.get("FCM_PRIVATE_KEY")!;
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;

// Cache the access token (valid for ~1 hour)
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Return cached token if still valid (with 5 min buffer)
  if (cachedToken && cachedToken.expiresAt > now + 300) {
    return cachedToken.token;
  }

  // Import the private key for signing
  const pemContent = FCM_PRIVATE_KEY.replace(/\\n/g, "\n");
  const pemBody = pemContent
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binaryKey = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  // Create JWT
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: FCM_CLIENT_EMAIL,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
    },
    cryptoKey
  );

  // Exchange JWT for access token
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await res.json();

  cachedToken = {
    token: tokenData.access_token,
    expiresAt: now + tokenData.expires_in,
  };

  return tokenData.access_token;
}

serve(async (req: Request) => {
  try {
    const payload = await req.json();

    // Database webhook sends the new row in payload.record
    const notification = payload.record ?? payload;

    const playerId = notification.player_id;
    const title = notification.title;
    const body = notification.body;
    const data = notification.data ?? {};

    if (!playerId || !title) {
      return new Response(
        JSON.stringify({ error: "Missing player_id or title" }),
        { status: 400 }
      );
    }

    // Get player's auth_id from players table
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: player, error: playerError } = await supabase
      .from("players")
      .select("auth_id")
      .eq("id", playerId)
      .single();

    if (playerError || !player) {
      return new Response(JSON.stringify({ error: "Player not found" }), {
        status: 404,
      });
    }

    // Get all FCM tokens for this player
    const { data: tokens, error: tokenError } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("player_auth_id", player.auth_id);

    if (tokenError || !tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No FCM tokens found" }),
        { status: 200 }
      );
    }

    // Get OAuth2 access token for FCM v1 API
    const accessToken = await getAccessToken();

    // Send push to all registered devices via FCM v1 API
    const results = await Promise.allSettled(
      tokens.map(async ({ token }: { token: string }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body },
                webpush: {
                  notification: {
                    icon: "/icons/Icon-192.png",
                    badge: "/icons/Icon-192.png",
                  },
                },
                data: Object.fromEntries(
                  Object.entries(data).map(([k, v]) => [k, String(v)])
                ),
              },
            }),
          }
        );

        const result = await res.json();

        // Remove invalid/expired tokens
        if (
          result.error?.code === 404 ||
          result.error?.details?.some(
            (d: { errorCode: string }) => d.errorCode === "UNREGISTERED"
          )
        ) {
          await supabase.from("fcm_tokens").delete().eq("token", token);
        }

        return result;
      })
    );

    return new Response(
      JSON.stringify({ sent: tokens.length, results }),
      { status: 200 }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }
});
