// Frozen production schema v6. Do not update this migration fixture.
const List<String> schemaV6Statements = <String>[
  // A deck's Library tile / Overview header offline, plus the columns the
  // offline-authoring sync surface needs (spec-v4). `course_id` mirrors
  // `decks.course_id`. `is_synced` flips to 0 on a local create / rename /
  // re-course and is walked by [SyncService]; `base_updated_at` is the last
  // Supabase `updated_at` seen. `is_pinned` is the device-local "keep
  // available offline" toggle (row existence alone just means "cached" — a
  // deck is mirrored the moment it is opened online). `mastery_level_sum` /
  // `total_cards` let the Library render counts for a deck that was listed
  // online but never opened, without mirroring its cards. `position` is the
  // manual order within the parent course (milestone B), stamped by an offline
  // drag and pushed via `set_deck_positions` on reconnect (milestone E3).
  '''
    CREATE TABLE offline_decks (
      id                TEXT PRIMARY KEY,
      name              TEXT NOT NULL,
      course_id         TEXT,
      last_studied_at   TEXT,
      created_at        TEXT,
      updated_at        TEXT,
      base_updated_at   TEXT,
      is_synced         INTEGER NOT NULL DEFAULT 1,
      is_pinned         INTEGER NOT NULL DEFAULT 0,
      mastery_level_sum INTEGER NOT NULL DEFAULT 0,
      total_cards       INTEGER NOT NULL DEFAULT 0,
      position          INTEGER NOT NULL DEFAULT 0
    )
    ''',
  // Courses are now editable offline (spec-v4), so this carries the same
  // dirty-flag columns as the other sync-surface tables. `user_id` is held so
  // the row can be upserted under RLS on reconnect. `position` is the manual
  // order within the user's course list (milestone B), stamped by an offline
  // drag and pushed via `set_course_positions` on reconnect (milestone E3).
  '''
    CREATE TABLE offline_courses (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL,
      accent_color    TEXT NOT NULL,
      is_default      INTEGER NOT NULL DEFAULT 0,
      user_id         TEXT,
      created_at      TEXT,
      updated_at      TEXT,
      base_updated_at TEXT,
      is_synced       INTEGER NOT NULL DEFAULT 1,
      position        INTEGER NOT NULL DEFAULT 0
    )
    ''',
  // Content mirror. `mastery_level` / `fail_count` are written locally during
  // offline study; front / back / keywords / is_concept are now editable
  // offline too (spec-v4) — a content edit sets `content_dirty = 1` so the
  // sync pass pushes a full upsert, distinct from the mastery-only
  // compare-and-set. `base_updated_at` is the Supabase `updated_at` last seen.
  //
  // `keyword` (singular) is a dead column since R3: Postgres replaced it with
  // `keywords text[]`, but SQLite `ALTER TABLE` here only ever adds columns
  // (and the schema-parity test can't parse a table rebuild), so the old
  // column stays, unread and unwritten. `keywords` is a JSON-encoded string
  // array; `is_concept` is 0/1. `created_locally = 1` marks a card authored
  // offline that has never reached Supabase, so a later offline delete skips
  // the remote DELETE — `base_updated_at` is NOT NULL here, so the null-probe
  // the deck/course tables use cannot serve (milestone E3).
  '''
    CREATE TABLE offline_cards (
      id              TEXT PRIMARY KEY,
      deck_id         TEXT NOT NULL,
      front           TEXT NOT NULL,
      back            TEXT NOT NULL,
      keyword         TEXT,
      keywords        TEXT NOT NULL DEFAULT '[]',
      is_concept      INTEGER NOT NULL DEFAULT 0,
      mastery_level   INTEGER NOT NULL,
      fail_count      INTEGER NOT NULL,
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL,
      base_updated_at TEXT NOT NULL,
      is_synced       INTEGER NOT NULL DEFAULT 1,
      content_dirty   INTEGER NOT NULL DEFAULT 0,
      created_locally INTEGER NOT NULL DEFAULT 0
    )
    ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  // Full local sessions — a session can be started and finished entirely
  // offline. `user_id` is carried so the row can be upserted under RLS later.
  // `card_scope` mirrors `study_sessions.card_scope` (engine-v2-spec §3.3).
  // `cards_reviewed` mirrors `study_sessions.cards_reviewed` — the distinct
  // card count stamped on completion, for the milestone-D profile metrics.
  '''
    CREATE TABLE offline_study_sessions (
      id             TEXT PRIMARY KEY,
      deck_id        TEXT NOT NULL,
      user_id        TEXT,
      status         TEXT NOT NULL,
      study_mode     TEXT NOT NULL,
      length_mode    TEXT NOT NULL,
      capped_length  INTEGER,
      card_scope     TEXT NOT NULL DEFAULT 'due',
      mastery_delta  INTEGER,
      cards_reviewed INTEGER,
      started_at     TEXT NOT NULL,
      completed_at   TEXT,
      is_synced      INTEGER NOT NULL DEFAULT 1
    )
    ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
    CREATE TABLE offline_session_cards (
      id                TEXT PRIMARY KEY,
      session_id        TEXT NOT NULL,
      card_id           TEXT NOT NULL,
      position          INTEGER NOT NULL,
      consecutive_fails INTEGER NOT NULL DEFAULT 0,
      is_parked         INTEGER NOT NULL DEFAULT 0,
      is_synced         INTEGER NOT NULL DEFAULT 1
    )
    ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
  // Tombstones for content deleted offline (spec-v4). [SyncService] replays
  // these on reconnect in reverse FK order (card, deck, course). `deck_id` is
  // held for a `card` tombstone so the push order can be resolved.
  // `created_locally = 1` marks a row that never reached Supabase, so its
  // remote delete is skipped.
  '''
    CREATE TABLE offline_deletions (
      entity_type     TEXT NOT NULL,
      entity_id       TEXT NOT NULL,
      deck_id         TEXT,
      created_locally INTEGER NOT NULL DEFAULT 0,
      created_at      TEXT NOT NULL
    )
    ''',
  'CREATE UNIQUE INDEX idx_offline_deletions_entity '
      'ON offline_deletions(entity_type, entity_id)',
  // A tiny key/value table for device-local sync bookkeeping (milestone E3).
  // Currently one row: `last_user_id`, so the whole mirror can be wiped when
  // the signed-in user changes (design spec §E.3 — the mirror is a private
  // file, not RLS-protected).
  '''
    CREATE TABLE offline_meta (
      key   TEXT PRIMARY KEY,
      value TEXT
    )
    ''',
];
