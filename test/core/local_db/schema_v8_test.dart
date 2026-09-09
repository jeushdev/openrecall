import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';
import 'package:sqflite/sqflite.dart';

import '../../support/local_db_harness.dart';
import '../../support/schema_v6.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'real v7 to v8 migration preserves data and backfills membership',
    () async {
      final directory = await Directory.systemTemp.createTemp('offline-v8-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/migration.db';
      final old = await openDatabase(
        path,
        version: 7,
        onCreate: (db, _) async {
          for (final statement in schemaV6Statements) {
            await db.execute(statement);
          }
          for (final statement in AppDatabase.upgradeToV7Statements) {
            await db.execute(statement);
          }
        },
      );
      await old.insert('offline_decks', {
        'id': 'complete',
        'name': 'Complete',
        'is_pinned': 1,
        'cards_complete': 1,
        'downloaded_at': '2026-09-07T00:00:00.000Z',
        'is_synced': 0,
      });
      await old.insert('offline_decks', {
        'id': 'partial',
        'name': 'Partial',
        'is_pinned': 1,
        'cards_complete': 0,
        'is_synced': 1,
      });
      for (final entry in const [
        ('member', 'complete'),
        ('partial-card', 'partial'),
      ]) {
        await old.insert('offline_cards', {
          'id': entry.$1,
          'deck_id': entry.$2,
          'front': 'Q',
          'back': 'A',
          'mastery_level': 2,
          'fail_count': 1,
          'created_at': '2026-09-07T00:00:00.000Z',
          'updated_at': '2026-09-07T00:00:00.000Z',
          'base_updated_at': '2026-09-06T00:00:00.000Z',
          'is_synced': entry.$1 == 'member' ? 0 : 1,
          'content_dirty': entry.$1 == 'member' ? 1 : 0,
          'created_locally': entry.$1 == 'member' ? 1 : 0,
        });
      }
      await old.insert('offline_study_sessions', {
        'id': 'session',
        'deck_id': 'complete',
        'user_id': 'owner',
        'status': 'completed',
        'study_mode': 'flip',
        'length_mode': 'uncapped',
        'started_at': '2026-09-07T00:00:00.000Z',
        'completed_at': '2026-09-07T01:00:00.000Z',
        'is_synced': 0,
      });
      await old.insert('offline_session_cards', {
        'id': 'queue',
        'session_id': 'session',
        'card_id': 'member',
        'position': 0,
        'is_synced': 0,
      });
      await old.insert('offline_deletions', {
        'entity_type': 'card',
        'entity_id': 'deleted',
        'deck_id': 'complete',
        'created_locally': 0,
        'created_at': '2026-09-07T00:00:00.000Z',
      });
      await old.close();

      var upgraded = await AppDatabase.open(path: path);
      expect(await upgraded.db.getVersion(), 8);
      final rows = await upgraded.db.query(
        'offline_cards',
        columns: ['id', 'in_current_package'],
        orderBy: 'id',
      );
      expect(rows, [
        {'id': 'member', 'in_current_package': 1},
        {'id': 'partial-card', 'in_current_package': 0},
      ]);
      final store = LocalDeckStore(upgraded.db);
      expect(
        (await store.packageStatus('complete')).availability,
        OfflinePackageAvailability.availableOffline,
      );
      expect(
        (await store.packageStatus('partial')).availability,
        OfflinePackageAvailability.incomplete,
      );
      expect(await store.deckHasUnsyncedWork('complete'), isTrue);
      expect(await upgraded.db.query('offline_study_sessions'), hasLength(1));
      expect(await upgraded.db.query('offline_session_cards'), hasLength(1));
      expect(await upgraded.db.query('offline_deletions'), hasLength(1));
      await store.setRemoteMissing('complete', missing: true);

      await upgraded.close();
      upgraded = await AppDatabase.open(path: path);
      addTearDown(upgraded.close);
      expect(
        (await LocalDeckStore(upgraded.db).packageStatus('complete'))
            .isExplicitlyAvailable,
        isTrue,
      );
      expect(
        (await LocalDeckStore(upgraded.db).packageStatus('complete'))
            .remoteMissing,
        isTrue,
      );
      expect(
        (await upgraded.db.query(
          'offline_cards',
          where: 'id = ?',
          whereArgs: ['member'],
        )).single['content_dirty'],
        1,
      );
    },
  );

  test('fresh v8 and upgraded v8 expose equivalent package columns', () async {
    final fresh = await openTestDatabase();
    addTearDown(fresh.close);
    for (final table in ['offline_decks', 'offline_cards']) {
      final columns = await fresh.db.rawQuery('PRAGMA table_info($table)');
      final names = {for (final row in columns) row['name']};
      if (table == 'offline_decks') {
        expect(names, containsAll(['remote_missing', 'cache_suppressed']));
      } else {
        expect(names, contains('in_current_package'));
      }
    }
  });
}
