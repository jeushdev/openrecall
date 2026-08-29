import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The device-local SQLite database (spec §10). Holds a per-deck mirror of the
/// `cards`, `study_sessions` and `session_cards` a downloaded deck needs to run
/// a study session with zero connectivity, plus small `offline_decks` /
/// `offline_courses` tables so the Deck Library and Deck Overview can render
/// those decks while offline.
///
/// Every study-mirror table carries one extra column Supabase does not have —
/// `is_synced` — which defaults to 1 when a row is pulled from Supabase and
/// flips to 0 the moment a local write happens. [SyncService] walks the 0 rows
/// on reconnect. `offline_decks` and `offline_courses` are read-only mirrors
/// with no `is_synced` (decks are never edited offline; course assignment is
/// online-only — engine-v2-spec §5). RLS is a Postgres concept only and does
/// not apply here: this is a private file on the user's own device.
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
  static const _version = 2;

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

  static const String _offlineCoursesTable = '''
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
    // Just enough of a deck to draw its Library tile and Overview header
    // offline. Decks are never edited offline (spec §10), so no `is_synced`.
    // `course_id` is a read-through mirror of `decks.course_id` (nullable here
    // is fine — engine-v2-spec §5).
    '''
    CREATE TABLE offline_decks (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL,
      course_id       TEXT,
      last_studied_at TEXT
    )
    ''',
    _offlineCoursesTable,
    // Read-only content mirror, except mastery_level / fail_count, which are
    // written locally during offline study. `base_updated_at` is the Supabase
    // `updated_at` last seen for this row — the compare-and-set target the sync
    // pass hands to `updateCardMasteryGuarded` (spec: never a blind update).
    '''
    CREATE TABLE offline_cards (
      id              TEXT PRIMARY KEY,
      deck_id         TEXT NOT NULL,
      front           TEXT NOT NULL,
      back            TEXT NOT NULL,
      keyword         TEXT,
      mastery_level   INTEGER NOT NULL,
      fail_count      INTEGER NOT NULL,
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL,
      base_updated_at TEXT NOT NULL,
      is_synced       INTEGER NOT NULL DEFAULT 1
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
  ];

  /// The delta from schema version 1 to version 2 (engine-v2-spec §5): the new
  /// `offline_courses` table plus the two added columns. All new columns have
  /// constant defaults, as SQLite's `ALTER TABLE ADD COLUMN` requires.
  @visibleForTesting
  static const List<String> upgradeToV2Statements = <String>[
    "ALTER TABLE offline_decks ADD COLUMN course_id TEXT",
    "ALTER TABLE offline_study_sessions "
        "ADD COLUMN card_scope TEXT NOT NULL DEFAULT 'due'",
    _offlineCoursesTable,
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
    await batch.commit(noResult: true);
  }
}
