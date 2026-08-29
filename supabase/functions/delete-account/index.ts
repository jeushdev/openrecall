// delete-account — permanently deletes the calling user's account (spec §9).
//
// The Supabase client SDK can't remove a user's own `auth.users` row, so the
// app calls this function. It verifies the caller from their bearer token, then
// uses the service-role key to delete the user. Everything else — decks, cards,
// study_sessions, session_cards — cascades away through the schema's
// `on delete cascade` foreign keys (see supabase/schema.sql).
//
// Deploy: see README.md in this folder. SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY are injected automatically into deployed functions.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';

  // Resolve the caller from their JWT using an anon-key client.
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await asUser.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Not authenticated' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Delete with the service-role client. The cascade handles the rest.
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);

  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(null, { status: 204, headers: corsHeaders });
});
