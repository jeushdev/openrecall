-- ActiveRecall — database schema (milestone 2)
--
-- The app talks to Supabase Postgres directly; there is no custom backend, so
-- the entire data model lives here. Apply this file once against a fresh
-- Supabase project via the SQL Editor.
--
-- Source of truth: the "Data Model (Schema)" section of docs/spec.md. The
-- create table / create index statements are copied verbatim from the spec;
-- the triggers and RLS policies are written out from the spec's prose.
--
-- This is a one-shot script — re-running it will error on the existing objects.

-- ---------------------------------------------------------------------------
-- Tables (verbatim from docs/spec.md, in foreign-key dependency order)
-- ---------------------------------------------------------------------------

-- profiles: app-specific fields on top of Supabase's built-in auth.users
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  tier text not null default 'free',
  created_at timestamptz not null default now()
);
-- trigger: auto-insert a profiles row whenever auth.users gets a new row

-- decks
create table decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  last_studied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- cards — the unified front/back/keyword model
create table cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references decks(id) on delete cascade,
  front text not null,
  back text not null,
  keyword text,
  mastery_level smallint not null default 0,  -- 0 Unfamiliar .. 4 Mastered
  fail_count integer not null default 0,      -- lifetime, feeds Troublemaker Cards
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- study_sessions — one row per study session, resumable
create table study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  deck_id uuid not null references decks(id) on delete cascade,
  status text not null default 'active',         -- active | completed | abandoned
  study_mode text not null,                      -- flip | cloze | list | feynman — which mode this session was studied in
  length_mode text not null default 'uncapped',  -- uncapped | capped (renamed from session_mode to avoid confusion with study_mode)
  capped_length integer,                         -- only set if length_mode = 'capped'
  mastery_delta smallint,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

-- session_cards — the queue + loop-prevention table, entirely session-scoped
create table session_cards (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references study_sessions(id) on delete cascade,
  card_id uuid not null references cards(id) on delete cascade,
  position integer not null,                      -- sparse (steps of 1000) so requeues don't need renumbering
  consecutive_fails smallint not null default 0,  -- resets on a pass, dies with the session
  is_parked boolean not null default false        -- session-scoped, unrelated to cards.fail_count
);

-- ---------------------------------------------------------------------------
-- profiles auto-creation trigger
--
-- spec §1: "a Postgres trigger on auth.users insert automatically creates the
-- matching profiles row. Not something the app itself has to remember to do
-- after signup."
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- updated_at triggers
--
-- spec: "since the entire sync design leans on updated_at for last-write-wins
-- conflict resolution, it's set by a database trigger on every UPDATE, not left
-- to the app to remember on each write path."
--
-- Only decks and cards have an updated_at column; profiles, study_sessions and
-- session_cards do not.
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger decks_set_updated_at
  before update on decks
  for each row execute function public.set_updated_at();

create trigger cards_set_updated_at
  before update on cards
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- spec "RLS ownership pattern": profiles, decks, study_sessions have a direct
-- user_id/id column → straightforward = auth.uid() policy. cards and
-- session_cards have no direct owner column on purpose — their policies check
-- ownership through a join (cards → decks.user_id, session_cards →
-- study_sessions.user_id).
--
-- One "for all" policy per table, scoped to authenticated users, with the same
-- ownership expression in USING (read/update/delete) and WITH CHECK
-- (insert/update) so a user can only ever touch their own rows.
-- ---------------------------------------------------------------------------

alter table profiles enable row level security;
alter table decks enable row level security;
alter table cards enable row level security;
alter table study_sessions enable row level security;
alter table session_cards enable row level security;

-- profiles: direct ownership (id is the auth.users id)
create policy profiles_owner on profiles
  for all
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- decks: direct ownership
create policy decks_owner on decks
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- study_sessions: direct ownership
create policy study_sessions_owner on study_sessions
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- cards: NO direct owner column — ownership is checked through the join to
-- decks.user_id. Read the generated policy SQL in Supabase and confirm this is
-- actually scoped correctly before trusting it (per CLAUDE.md).
create policy cards_owner_via_deck on cards
  for all
  to authenticated
  using (
    exists (
      select 1 from decks
      where decks.id = cards.deck_id
        and decks.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from decks
      where decks.id = cards.deck_id
        and decks.user_id = (select auth.uid())
    )
  );

-- session_cards: NO direct owner column — ownership is checked through the join
-- to study_sessions.user_id. Same caution as cards above.
create policy session_cards_owner_via_session on session_cards
  for all
  to authenticated
  using (
    exists (
      select 1 from study_sessions s
      where s.id = session_cards.session_id
        and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from study_sessions s
      where s.id = session_cards.session_id
        and s.user_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- Indexes (verbatim from docs/spec.md)
--
-- spec: foreign key columns are not indexed automatically by Postgres the way
-- primary keys are — see "Performance & Responsiveness".
-- ---------------------------------------------------------------------------

create index on decks (user_id);
create index on cards (deck_id);
create index on study_sessions (user_id);
create index on study_sessions (deck_id);
create index on session_cards (session_id);
create index on session_cards (card_id);
