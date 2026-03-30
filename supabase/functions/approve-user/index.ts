import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const validRoles = new Set([
  "admin",
  "manager",
  "supervisor",
  "engineer",
  "technician",
  "user",
  "partner_user",
  "pending",
]);

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
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
      return jsonResponse({ error: "Supabase function secrets eksik." }, 500);
    }

    if (!authHeader) {
      return jsonResponse({ error: "Authorization header eksik." }, 401);
    }

    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const {
      data: { user: actor },
      error: actorError,
    } = await callerClient.auth.getUser();

    if (actorError || !actor) {
      return jsonResponse(
        { error: actorError?.message ?? "Oturum dogrulanamadi." },
        401,
      );
    }

    const { data: actorProfile, error: actorProfileError } = await adminClient
      .from("profiles")
      .select("role")
      .eq("id", actor.id)
      .maybeSingle();

    if (actorProfileError) {
      return jsonResponse({ error: actorProfileError.message }, 500);
    }

    if (!actorProfile || !["admin", "manager"].includes(actorProfile.role)) {
      return jsonResponse({ error: "Bu islem icin yetkiniz yok." }, 403);
    }

    const body = await req.json();
    const userId = body.userId as string?;
    const role = body.role as string?;
    const partnerId = (body.partnerId as number | null | undefined) ?? null;

    if (!userId || !role) {
      return jsonResponse({ error: "userId ve role zorunludur." }, 400);
    }

    if (!validRoles.has(role)) {
      return jsonResponse({ error: "Gecersiz rol secimi." }, 400);
    }

    if (role === "partner_user" && partnerId == null) {
      return jsonResponse(
        { error: "Partner kullanicisi icin partner secilmelidir." },
        400,
      );
    }

    const { data: targetUserData, error: targetUserError } =
      await adminClient.auth.admin.getUserById(userId);

    if (targetUserError || !targetUserData.user) {
      return jsonResponse(
        { error: targetUserError?.message ?? "Auth kullanicisi bulunamadi." },
        404,
      );
    }

    const targetUser = targetUserData.user;

    const { error: profileError } = await adminClient.from("profiles").upsert({
      id: targetUser.id,
      email: targetUser.email,
      full_name:
        targetUser.user_metadata?.full_name ??
        targetUser.user_metadata?.name ??
        targetUser.email,
      role,
      partner_id: role === "partner_user" ? partnerId : null,
    });

    if (profileError) {
      return jsonResponse({ error: profileError.message }, 500);
    }

    if (role !== "pending") {
      const { error: confirmError } = await adminClient.auth.admin
        .updateUserById(userId, {
          email_confirm: true,
        });

      if (confirmError) {
        return jsonResponse({ error: confirmError.message }, 500);
      }
    }

    return jsonResponse({
      success: true,
      userId,
      role,
      emailConfirmed: role !== "pending",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});


