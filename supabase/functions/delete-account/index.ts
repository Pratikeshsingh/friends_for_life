import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ message: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ message: "Sign in before deleting your account." }, 401);
  }

  let body: { confirmation?: string };
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ message: "Invalid request." }, 400);
  }

  if (body.confirmation !== "DELETE") {
    return jsonResponse({ message: "Deletion was not confirmed." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Required Supabase environment variables are unavailable.");
    return jsonResponse({ message: "Account deletion is temporarily unavailable." }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return jsonResponse({ message: "Your session has expired. Sign in again." }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Supabase Auth refuses to delete a user who still owns Storage objects.
  // VriendTime stores all member photos directly inside this user-id folder.
  const photoPaths: string[] = [];
  let offset = 0;
  const pageSize = 100;
  while (true) {
    const { data: entries, error: listError } = await admin.storage
      .from("profile-photos")
      .list(user.id, { limit: pageSize, offset });

    if (listError) {
      // A missing bucket means this account has no deployed photo storage yet.
      if (!listError.message.toLowerCase().includes("not found")) {
        console.error("Could not list profile photos:", listError.message);
        return jsonResponse(
          { message: "We could not remove your profile photos. Please try again." },
          500,
        );
      }
      break;
    }

    const files = (entries ?? []).filter((entry) => entry.id != null);
    photoPaths.push(...files.map((entry) => `${user.id}/${entry.name}`));
    if ((entries?.length ?? 0) < pageSize) break;
    offset += pageSize;
  }

  for (let index = 0; index < photoPaths.length; index += 100) {
    const { error: removeError } = await admin.storage
      .from("profile-photos")
      .remove(photoPaths.slice(index, index + 100));
    if (removeError) {
      console.error("Could not remove profile photos:", removeError.message);
      return jsonResponse(
        { message: "We could not remove your profile photos. Please try again." },
        500,
      );
    }
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("Could not delete Auth user:", deleteError.message);
    return jsonResponse(
      { message: "We could not delete your account. Please try again." },
      500,
    );
  }

  return jsonResponse({ deleted: true });
});
