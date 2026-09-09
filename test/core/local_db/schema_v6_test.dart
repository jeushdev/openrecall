import 'package:flutter_test/flutter_test.dart';

import '../../support/local_db_harness.dart';

/// The v6 schema (milestone E3) against a real SQLite database: the two new
/// `position` columns default to 0, `offline_cards.created_locally` defaults to
/// 0, and `offline_meta` round-trips a key/value row.
void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'a fresh v6 database has the reorder columns and offline_meta',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final db = database.db;

      await db.insert('offline_decks', {'id': 'd1', 'name': 'A'});
      await db.insert('offline_courses', {
        'id': 'c1',
        'name': 'Bio',
        'accent_color': 'green',
      });
      await db.insert('offline_cards', {
        'id': 'k1',
        'deck_id': 'd1',
        'front': 'Q',
        'back': 'A',
        'mastery_level': 0,
        'fail_count': 0,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'base_updated_at': '2026-01-01T00:00:00.000Z',
      });

      final deck = (await db.query(
        'offline_decks',
        where: 'id = ?',
        whereArgs: ['d1'],
      )).single;
      final course = (await db.query(
        'offline_courses',
        where: 'id = ?',
        whereArgs: ['c1'],
      )).single;
      final card = (await db.query(
        'offline_cards',
        where: 'id = ?',
        whereArgs: ['k1'],
      )).single;
      expect(deck['position'], 0);
      expect(course['position'], 0);
      expect(card['created_locally'], 0);

      await db.insert('offline_meta', {
        'key': 'last_user_id',
        'value': 'user-a',
      });
      final meta = (await db.query(
        'offline_meta',
        where: 'key = ?',
        whereArgs: ['last_user_id'],
      )).single;
      expect(meta['value'], 'user-a');
    },
  );
}
