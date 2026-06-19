import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const oneSignalRestApiKey = Deno.env.get("ONESIGNAL_REST_API_KEY");
    const configuredOneSignalAppId = Deno.env.get("ONESIGNAL_APP_ID");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !supabaseAnonKey) {
      return jsonResponse({ error: "Supabase function secrets eksik." }, 500);
    }

    if (!oneSignalRestApiKey) {
      return jsonResponse({ error: "ONESIGNAL_REST_API_KEY eksik." }, 500);
    }

    if (!authHeader) {
      return jsonResponse({ error: "Authorization header eksik." }, 401);
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse(
        { error: userError?.message ?? "Oturum dogrulanamadi." },
        401,
      );
    }

    const body = await req.json();
    const appId = (body.app_id as string | undefined) ?? configuredOneSignalAppId;
    const headings = body.headings as Record<string, string> | undefined;
    const contents = body.contents as Record<string, string> | undefined;
    const data = body.data as Record<string, unknown> | undefined;
    const includeExternalUserIds = body.include_external_user_ids as
      | string[]
      | undefined;
    const includePlayerIds = body.include_player_ids as string[] | undefined;
    const includedSegments = body.included_segments as string[] | undefined;

    if (!appId) {
      return jsonResponse({ error: "OneSignal app id bulunamadi." }, 400);
    }

    if (!headings || !contents) {
      return jsonResponse(
        { error: "headings ve contents zorunludur." },
        400,
      );
    }

    const hasTarget =
      (includeExternalUserIds?.length ?? 0) > 0 ||
      (includePlayerIds?.length ?? 0) > 0 ||
      (includedSegments?.length ?? 0) > 0;

    if (!hasTarget) {
      return jsonResponse(
        { error: "En az bir bildirim hedefi gonderilmelidir." },
        400,
      );
    }

    const oneSignalResponse = await fetch(
      "https://onesignal.com/api/v1/notifications",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${oneSignalRestApiKey}`,
        },
        body: JSON.stringify({
          app_id: appId,
          headings,
          contents,
          data: data ?? {},
          ...(includeExternalUserIds?.length
            ? { include_external_user_ids: includeExternalUserIds }
            : {}),
          ...(includePlayerIds?.length
            ? { include_player_ids: includePlayerIds }
            : {}),
          ...(includedSegments?.length
            ? { included_segments: includedSegments }
            : {}),
        }),
      },
    );

    const responseText = await oneSignalResponse.text();
    let responseBody: unknown = responseText;
    try {
      responseBody = JSON.parse(responseText);
    } catch (_) {
      // Keep raw text when OneSignal does not return JSON.
    }

    if (!oneSignalResponse.ok) {
      return jsonResponse(
        {
          error: "OneSignal bildirimi gonderilemedi.",
          status: oneSignalResponse.status,
          body: responseBody,
        },
        502,
      );
    }

    return jsonResponse({
      success: true,
      actorUserId: user.id,
      oneSignal: responseBody,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});
