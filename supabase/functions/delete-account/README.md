# delete-account Edge Function

Permanently deletes the calling user's account (spec §9). The app invokes this
from the Settings screen because the client SDK cannot delete a user's own
`auth.users` row. Once the row is gone, all of that user's decks, cards and
sessions cascade away through the foreign keys defined in `supabase/schema.sql`.

## Deploy (one-time, manual — same as applying `schema.sql`)

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli) and a linked
project (`supabase link --project-ref <ref>`).

```bash
supabase functions deploy delete-account
```

No secrets to set: `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` are injected automatically into every deployed
function.

`verify_jwt` is left at its default (on). The Flutter app calls the function via
`supabase.functions.invoke('delete-account')`, which attaches the signed-in
user's bearer token; the function reads that token to identify who to delete.

## Contract

- `POST` (no body). Auth: the caller's JWT in the `Authorization` header.
- `204 No Content` — account deleted.
- `401` — no valid session.
- `500` — deletion failed (body: `{ "error": "<message>" }`).
