import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The device-local SQLite database (spec §10). Holds a per-deck mirror of the
/// `cards`, `study_sessions` and `session_cards` a downloaded deck needs to run
/// a study session with zero connectivity, plus small `offline_decks` /
/// `offline_courses` tables so the Deck Library and Deck Overview can render
/// those decks while offline.
///
/// Every sync-surface table carries one extra column Supabase does not have —
/// `is_synced` — which defaults to 1 when a row is pulled from Supabase and
/// flips to 0 the moment a local write happens. [SyncService] walks the 0 rows
/// on reconnect. Since spec-v4 that surface includes `offline_courses` and
/// `offline_decks` (courses, decks and cards are all editable offline now), and
/// `offline_deletions` holds tombstones for rows deleted offline. RLS is a
/// Postgres concept only and does not apply here: this is a private file on the
/// user's own device.
///
/// The schema is defined as ordered statement lists so [_createSchema] (a fresh
/// install) and [_onUpgrade] (an in-place migration) cannot drift apart — the
/// schema-parity test asserts that a fresh v2 database and a v1 database
/// upgraded to v2 describe the same tables and columns.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// The open handle. Only valid after [open].
  Database get db => _db;

  static const _fileName = 'open_recall.db';

  /// Bump this and add a step to [_onUpgrade] whenever [schemaStatements]
  /// changes.
  static const _version = 4;

  /// Opens (creating on first run) the database. [path] overrides the platform
  /// default and is only passed by tests.
  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      dbPath,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(db);
  }

  Future<void> close() => _db.close();

  // ---- schema ---------------------------------------------------------------

  /// The frozen v2 `offline_courses` definition. Used only by
  /// [upgradeToV2Statements] — the fresh schema builds the current, wider
  /// `offline_courses` inline in [schemaStatements].
  static const String _offlineCoursesTableV2 = '''
    CREATE TABLE offline_courses (
      id           TEXT PRIMARY KEY,
      name         TEXT NOT NULL,
      accent_color TEXT NOT NULL,
      is_default   INTEGER NOT NULL DEFAULT 0
    )
  ''';

  /// Every statement that builds the current (v2) schema, in order. A fresh
  /// install executes exactly this list.
  @visibleForTesting
  static const List<String> schemaStatements = <String>[
    // A deck's Library tile / Overview header offline, plus the columns the
    // offline-authoring sync surface needs (spec-v4). `course_id` mirrors
    // `decks.course_id`. `is_synced` flips to 0 on a local create / rename /
    // re-course and is walked by [SyncService]; `base_updated_at` is the last
    // Supabase `updated_at` seen. `is_pinned` is the device-local "keep
    // available offline" toggle (row existence alone just means "cached" — a
    // deck is mirrored the moment it is opened online). `mastery_level_sum` /
    // `total_cards` let the Library render counts for a deck that was listed
    // online but never opened, without mirroring its cards.
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
      total_cards       INTEGER NOT NULL DEFAULT 0
    )
    ''',
    // Courses are now editable offline (spec-v4), so this carries the same
    // dirty-flag columns as the other sync-surface tables. `user_id` is held so
    // the row can be upserted under RLS on reconnect.
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
      is_synced       INTEGER NOT NULL DEFAULT 1
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
    // array; `is_concept` is 0/1.
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
      content_dirty   INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
    // Full local sessions — a session can be started and finished entirely
    // offline. `user_id` is carried so the row can be upserted under RLS later.
    // `card_scope` mirrors `study_sessions.card_scope` (engine-v2-spec §3.3).
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
  ];

  /// The delta from schema version 1 to version 2 (engine-v2-spec §5): the new
  /// `offline_courses` table plus the two added columns. All new columns have
  /// constant defaults, as SQLite's `ALTER TABLE ADD COLUMN` requires.
  @visibleForTesting
  static const List<String> upgradeToV2Statements = <String>[
    "ALTER TABLE offline_decks ADD COLUMN course_id TEXT",
    "ALTER TABLE offline_study_sessions "
        "ADD COLUMN card_scope TEXT NOT NULL DEFAULT 'due'",
    _offlineCoursesTableV2,
  ];

  /// The delta from schema version 2 to version 3 (docs/spec-v3-card-model.md):
  /// the multi-keyword + concept card model. The old `keyword` column is left in
  /// place (SQLite migrations here only add columns). All new columns have
  /// constant defaults, as `ALTER TABLE ADD COLUMN` requires.
  @visibleForTesting
  static const List<String> upgradeToV3Statements = <String>[
    "ALTER TABLE offline_cards ADD COLUMN keywords TEXT NOT NULL DEFAULT '[]'",
    "ALTER TABLE offline_cards ADD COLUMN is_concept INTEGER NOT NULL DEFAULT 0",
  ];

  /// The delta from schema version 3 to version 4
  /// (docs/spec-v4-offline-authoring.md): the offline-authoring sync surface.
  /// Courses and decks gain the same dirty-flag columns the study-mirror tables
  /// already have, cards gain `content_dirty`, and a tombstone table is added
  /// for offline deletes. All added columns have constant defaults, as
  /// `ALTER TABLE ADD COLUMN` requires.
  @visibleForTesting
  static const List<String> upgradeToV4Statements = <String>[
    'ALTER TABLE offline_decks ADD COLUMN created_at TEXT',
    'ALTER TABLE offline_decks ADD COLUMN updated_at TEXT',
    'ALTER TABLE offline_decks ADD COLUMN base_updated_at TEXT',
    'ALTER TABLE offline_decks ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1',
    'ALTER TABLE offline_decks ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE offline_decks '
        'ADD COLUMN mastery_level_sum INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE offline_decks '
        'ADD COLUMN total_cards INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE offline_courses ADD COLUMN user_id TEXT',
    'ALTER TABLE offline_courses ADD COLUMN created_at TEXT',
    'ALTER TABLE offline_courses ADD COLUMN updated_at TEXT',
    'ALTER TABLE offline_courses ADD COLUMN base_updated_at TEXT',
    'ALTER TABLE offline_courses '
        'ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 1',
    'ALTER TABLE offline_cards '
        'ADD COLUMN content_dirty INTEGER NOT NULL DEFAULT 0',
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
  ];

  static Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    for (final statement in schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    final batch = db.batch();
    if (oldVersion < 2) {
      for (final statement in upgradeToV2Statements) {
        batch.execute(statement);
      }
    }
    if (oldVersion < 3) {
      for (final statement in upgradeToV3Statements) {
        batch.execute(statement);
      }
    }
    if (oldVersion < 4) {
      for (final statement in upgradeToV4Statements) {
        batch.execute(statement);
      }
    }
    await batch.commit(noResult: true);
  }
}
