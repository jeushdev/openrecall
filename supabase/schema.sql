-- ActiveRecall — database schema (Engine V2, milestone 15)
--
-- The app talks to Supabase Postgres directly; there is no custom backend, so
-- the entire data model lives here. Apply this file once against a fresh
-- Supabase project via the SQL Editor.
--
-- Source of truth: the "Data Model (Schema)" section of docs/spec.md, as
-- amended by docs/engine-v2-spec.md §3 (the `courses` table, `decks.course_id`,
-- `study_sessions.card_scope`). The create table / create index statements are
-- copied from those specs; the triggers and RLS policies are written out from
-- their prose.
--
-- The live Supabase project holds test accounts only, so this is a fresh
-- re-apply rather than a migration. The one-time backfill block at the end lets
-- the same file run cleanly whether the project is empty or already has test
-- decks. Re-running the whole file will error on the existing objects.

-- ---------------------------------------------------------------------------
-- Tables (in foreign-key dependency order)
-- ---------------------------------------------------------------------------

-- profiles: app-specific fields on top of Supabase's built-in auth.users
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  tier text not null default 'free',
  created_at timestamptz not null default now()
);
-- trigger: auto-insert a profiles row (and a default course) on auth.users insert

-- courses — the top-level grouping a deck belongs to (engine-v2-spec §3.1).
-- Every user has exactly one `is_default` course; a deck with no explicit
-- course is attached to it by the decks BEFORE INSERT trigger below.
create table courses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references profiles(id) on delete cascade,
  name         text not null,
  accent_color text not null,
  is_default   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Named so a future palette change is a clean drop/add. These are named keys
  -- mapped to hex in the Flutter theme layer, not arbitrary colour strings.
  -- 'slate' is the neutral default and must always be a member of the set.
  constraint courses_accent_color_check
    check (accent_color in
      ('slate','red','amber','green','teal','blue','violet','pink'))
);

-- decks
--
-- course_id is created nullable here and made NOT NULL at the end of the file,
-- after the backfill, so this script runs on a project that already has decks
-- (engine-v2-spec §3.2). The FK action stays NO ACTION (the default): deleting
-- a profiles row cascades to decks and courses in the same statement, and
-- NO ACTION defers the check to statement end so that simultaneous cascade
-- succeeds — ON DELETE RESTRICT would spuriously fail account deletion.
create table decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  course_id uuid references courses(id),
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
  -- Queue-selection metadata, not a mode (engine-v2-spec §3.3): 'due' is the V1
  -- behaviour (only cards below Mastered), 'all' also drills already-Mastered
  -- cards. Makes "times fully cleared" derivable: card_scope='all' and
  -- status='completed'.
  card_scope text not null default 'due' check (card_scope in ('due','all')),
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
-- New-user trigger
--
-- spec §1: "a Postgres trigger on auth.users insert automatically creates the
-- matching profiles row." engine-v2-spec §3.4 extends it so the same trigger
-- also creates the user's default course, after the profiles insert (FK order).
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

  insert into public.courses (user_id, name, accent_color, is_default)
  values (new.id, 'Uncategorized', 'slate', true);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Default-course trigger on decks
--
-- engine-v2-spec §3.2: when a deck is inserted with course_id null, fill it
-- from the inserting user's is_default course. Keeps course_id NOT NULL with
-- zero client changes and covers every insert path (manual, bulk paste, tests,
-- any future import).
-- ---------------------------------------------------------------------------

create or replace function public.decks_fill_default_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.course_id is null then
    select c.id into new.course_id
    from public.courses c
    where c.user_id = new.user_id and c.is_default;
  end if;
  return new;
end;
$$;

create trigger decks_fill_default_course
  before insert on decks
  for each row execute function public.decks_fill_default_course();

-- ---------------------------------------------------------------------------
-- updated_at triggers
--
-- spec: "since the entire sync design leans on updated_at for last-write-wins
-- conflict resolution, it's set by a database trigger on every UPDATE, not left
-- to the app to remember on each write path."
--
-- Only courses, decks and cards have an updated_at column; profiles,
-- study_sessions and session_cards do not.
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

create trigger courses_set_updated_at
  before update on courses
  for each row execute function public.set_updated_at();

create trigger decks_set_updated_at
  before update on decks
  for each row execute function public.set_updated_at();

create trigger cards_set_updated_at
  before update on cards
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- spec "RLS ownership pattern": profiles, courses, decks, study_sessions have a
-- direct user_id/id column → straightforward = auth.uid() policy. cards and
-- session_cards have no direct owner column on purpose — their policies check
-- ownership through a join (cards → decks.user_id, session_cards →
-- study_sessions.user_id).
--
-- One "for all" policy per table, scoped to authenticated users, with the same
-- ownership expression in USING (read/update/delete) and WITH CHECK
-- (insert/update) so a user can only ever touch their own rows.
-- ---------------------------------------------------------------------------

alter table profiles enable row level security;
alter table courses enable row level security;
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

-- courses: direct ownership
create policy courses_owner on courses
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- decks: direct ownership, plus a course-ownership clause in WITH CHECK. The FK
-- only proves the course exists, not that the user owns it, so without this a
-- client could attach its deck to someone else's course_id (engine-v2-spec
-- §3.2).
create policy decks_owner on decks
  for all
  to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from courses c
      where c.id = decks.course_id
        and c.user_id = (select auth.uid())
    )
  );

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
-- Indexes
--
-- spec: foreign key columns are not indexed automatically by Postgres the way
-- primary keys are — see "Performance & Responsiveness".
-- ---------------------------------------------------------------------------

create index on courses (user_id);
-- exactly one default course per user
create unique index courses_one_default_per_user
  on courses (user_id) where is_default;

create index on decks (user_id);
create index on decks (course_id);
create index on cards (deck_id);
-- Headroom for the app-wide Troublemakers query (engine-v2-spec §6):
-- `order by fail_count desc limit N` across every card the user owns.
create index on cards (fail_count desc);
create index on study_sessions (user_id);
create index on study_sessions (deck_id);
create index on session_cards (session_id);
create index on session_cards (card_id);

-- ---------------------------------------------------------------------------
-- One-time backfill (engine-v2-spec §3.4)
--
-- No-ops on a fresh project. On a project that already has test data: give
-- every profile a default course, attach every orphan deck to its owner's
-- default course, then make decks.course_id NOT NULL.
-- ---------------------------------------------------------------------------

insert into courses (user_id, name, accent_color, is_default)
select p.id, 'Uncategorized', 'slate', true
from profiles p
where not exists (
  select 1 from courses c where c.user_id = p.id and c.is_default
);

update decks d
set course_id = (
  select c.id from courses c
  where c.user_id = d.user_id and c.is_default
)
where d.course_id is null;

alter table decks alter column course_id set not null;
