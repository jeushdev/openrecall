import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The device-local SQLite database (spec §10). Holds a per-deck mirror of the
/// `cards`, `study_sessions` and `session_cards` a downloaded deck needs to run
/// a study session with zero connectivity, plus a small `offline_decks` table so
/// the Deck Library and Deck Overview can render those decks while offline.
///
/// Every mirror table carries one extra column Supabase does not have —
/// `is_synced` — which defaults to 1 when a row is pulled from Supabase and
/// flips to 0 the moment a local write happens. [SyncService] walks the 0 rows
/// on reconnect. RLS is a Postgres concept only and does not apply here: this is
/// a private file on the user's own device.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// The open handle. Only valid after [open].
  Database get db => _db;

  static const _fileName = 'open_recall.db';
  static const _version = 1;

  /// Opens (creating on first run) the database at the platform's default
  /// databases directory.
  static Future<AppDatabase> open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    return AppDatabase._(db);
  }

  Future<void> close() => _db.close();

  static Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

    // Just enough of a deck to draw its Library tile and Overview header
    // offline. Decks are never edited offline (spec §10), so no `is_synced`.
    batch.execute('''
      CREATE TABLE offline_decks (
        id              TEXT PRIMARY KEY,
        name            TEXT NOT NULL,
        last_studied_at TEXT
      )
    ''');

    // Read-only content mirror, except mastery_level / fail_count, which are
    // written locally during offline study. `base_updated_at` is the Supabase
    // `updated_at` last seen for this row — the compare-and-set target the sync
    // pass hands to `updateCardMasteryGuarded` (spec: never a blind update).
    batch.execute('''
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
    ''');
    batch.execute('CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)');

    // Full local sessions — a session can be started and finished entirely
    // offline. `user_id` is carried so the row can be upserted under RLS later.
    batch.execute('''
      CREATE TABLE offline_study_sessions (
        id             TEXT PRIMARY KEY,
        deck_id        TEXT NOT NULL,
        user_id        TEXT,
        status         TEXT NOT NULL,
        study_mode     TEXT NOT NULL,
        length_mode    TEXT NOT NULL,
        capped_length  INTEGER,
        mastery_delta  INTEGER,
        started_at     TEXT NOT NULL,
        completed_at   TEXT,
        is_synced      INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)');

    batch.execute('''
      CREATE TABLE offline_session_cards (
        id                TEXT PRIMARY KEY,
        session_id        TEXT NOT NULL,
        card_id           TEXT NOT NULL,
        position          INTEGER NOT NULL,
        consecutive_fails INTEGER NOT NULL DEFAULT 0,
        is_parked         INTEGER NOT NULL DEFAULT 0,
        is_synced         INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_offline_session_cards_session ON offline_session_cards(session_id)');

    await batch.commit(noResult: true);
  }
}
