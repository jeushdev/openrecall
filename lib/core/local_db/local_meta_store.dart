import 'package:sqflite/sqflite.dart';

/// DAO for `offline_meta` — a one-row-per-key device-local scratch table
/// (milestone E3).
///
/// Today it holds a single key, `last_user_id`, so [MirrorScopeGuard] can tell
/// when the signed-in account has changed and the whole local mirror must be
/// dropped (design spec §E.3: the mirror is a private file, not RLS-protected,
/// so one account's downloaded decks would otherwise be visible to the next).
///
/// A `null` database (the default outside `main()`) makes every method a no-op.
class LocalMetaStore {
  LocalMetaStore(this._db);

  final Database? _db;

  static const _userKey = 'last_user_id';

  /// Every mirrored table, wiped on an account switch. `offline_meta` itself is
  /// deliberately absent — the marker must survive the wipe.
  static const _mirrorTables = <String>[
    'offline_cards',
    'offline_session_cards',
    'offline_study_sessions',
    'offline_decks',
    'offline_courses',
    'offline_deletions',
  ];

  Future<String?> lastUserId() async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('offline_meta',
        columns: ['value'], where: 'key = ?', whereArgs: [_userKey], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setLastUserId(String id) async {
    final db = _db;
    if (db == null) return;
    await db.insert('offline_meta', {'key': _userKey, 'value': id},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Deletes every mirrored row — decks, cards, sessions, courses, tombstones.
  /// `offline_meta` itself is left intact.
  Future<void> wipeMirror() async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final table in _mirrorTables) {
        await txn.delete(table);
      }
    });
  }
}
