import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/core/local_db/application_cache.dart';
import 'package:open_recall/core/local_db/local_meta_store.dart';
import 'package:open_recall/core/local_db/stale_account_scope.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/local_db_harness.dart';
import '../../support/schema_v6.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test('v6 upgrade preserves dirty rows, pins, IDs and tombstones', () async {
    final directory = await Directory.systemTemp.createTemp('offline-v8-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/migration.db';
    final old = await openDatabase(
      path,
      version: 6,
      onCreate: (db, _) async {
        for (final statement in schemaV6Statements) {
          await db.execute(statement);
        }
      },
    );
    await old.insert('offline_decks', {
      'id': 'deck',
      'name': 'Biology',
      'is_pinned': 1,
      'is_synced': 0,
    });
    await old.insert('offline_cards', {
      'id': 'card',
      'deck_id': 'deck',
      'front': 'Q',
      'back': 'A',
      'mastery_level': 2,
      'fail_count': 3,
      'created_at': '2026-09-07',
      'updated_at': '2026-09-07',
      'base_updated_at': '2026-09-06',
      'is_synced': 0,
      'content_dirty': 1,
      'created_locally': 1,
    });
    await old.insert('offline_study_sessions', {
      'id': 'session',
      'deck_id': 'deck',
      'user_id': 'a',
      'status': 'active',
      'study_mode': 'flip',
      'length_mode': 'until_mastered',
      'started_at': '2026-09-07',
      'is_synced': 0,
    });
    await old.insert('offline_session_cards', {
      'id': 'queue',
      'session_id': 'session',
      'card_id': 'card',
      'position': 10,
      'is_synced': 0,
    });
    await old.insert('offline_deletions', {
      'entity_type': 'card',
      'entity_id': 'deleted',
      'created_at': '2026-09-07',
    });
    final before = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'offline_cards',
      'offline_study_sessions',
      'offline_session_cards',
      'offline_deletions',
    ]) {
      before[table] = await old.query(table);
    }
    await old.close();
    final upgraded = await AppDatabase.open(path: path);
    addTearDown(upgraded.close);
    expect(await upgraded.db.getVersion(), 8);
    for (final table in before.keys) {
      final queried = await upgraded.db.query(table);
      final after = table == 'offline_cards'
          ? [
              for (final row in queried)
                Map.of(row)..remove('in_current_package'),
            ]
          : queried;
      expect(after, before[table]);
    }
    final deck = (await upgraded.db.query('offline_decks')).single;
    expect(deck['is_pinned'], 1);
    expect(deck['is_synced'], 0);
    expect(deck['cards_complete'], 0);
    expect(deck['downloaded_at'], isNull);

    final fresh = await AppDatabase.open(path: '${directory.path}/fresh.db');
    addTearDown(fresh.close);
    final tables = await fresh.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    for (final table in tables) {
      final name = table['name'];
      // ALTER TABLE appends columns; physical ordinal is not schema identity.
      Future<Map<String, Map<String, Object?>>> columns(Database db) async => {
        for (final row in await db.rawQuery('PRAGMA table_info($name)'))
          row['name'] as String: Map.of(row)..remove('cid'),
      };
      expect(await columns(upgraded.db), await columns(fresh.db));
    }
  });

  test(
    'cache distinguishes missing, partial, complete-empty and unavailable',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final cache = ApplicationCache(database.db);
      expect(cache.isAvailable, isTrue);
      expect(await cache.metadata('history'), isNull);
      await cache.markFetched('history', coverage: CacheCoverage.partial);
      expect(
        (await cache.metadata('history'))!.coverage,
        CacheCoverage.partial,
      );
      await cache.markFetched('history');
      expect(
        (await cache.metadata('history'))!.coverage,
        CacheCoverage.complete,
      );
      expect(await database.db.query('offline_study_sessions'), isEmpty);
      await cache.saveProfile((
        id: 'a',
        email: 'a@example.com',
        username: 'Ada',
      ));
      expect((await cache.profile())!.username, 'Ada');
      await cache.saveProfile((
        id: 'a',
        email: 'a@example.com',
        username: null,
      ));
      expect((await cache.profile())!.username, isNull);
      final absent = ApplicationCache(null);
      expect(absent.isAvailable, isFalse);
      await absent.markFetched('history');
      expect(await absent.metadata('history'), isNull);
    },
  );

  test('same account retains data; another account revokes old handles and clears all caches', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    await database.scopeAccount('a');
    final generation = database.scopeGeneration;
    bool current() =>
        database.scopeReady && database.scopeGeneration == generation;
    final cache = ApplicationCache(database.db, isCurrent: current);
    final decks = LocalDeckStore(database.db, isCurrent: current);
    await cache.saveProfile((id: 'a', email: 'a@example.com', username: 'Ada'));
    await cache.markFetched('history');
    await database.db.insert('offline_decks', {
      'id': 'd',
      'name': 'A',
      'is_synced': 0,
    });
    await database.db.insert('cached_active_progress', {
      'session_id': 's',
      'mastered': 1,
      'total': 2,
    });
    await database.scopeAccount('a');
    expect(database.scopeGeneration, generation);
    expect((await cache.profile())!.username, 'Ada');
    final switching = database.scopeAccount('b');
    expect(database.scopeReady, isFalse);
    await expectLater(
      cache.saveProfile((id: 'a', email: 'a@example.com', username: 'Late')),
      throwsA(isA<StaleAccountScope>()),
    );
    await expectLater(
      decks.cachedDeckSummaries(),
      throwsA(isA<StaleAccountScope>()),
    );
    await switching;
    expect(database.scopeReady, isTrue);
    expect(await LocalMetaStore(database.db).lastUserId(), 'b');
    for (final table in [
      'cached_profile',
      'application_cache',
      'cached_active_progress',
      'offline_decks',
    ]) {
      expect(await database.db.query(table), isEmpty);
    }
  });

  test('overlapping switches finish with the last requested owner', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final first = database.scopeAccount('a');
    final second = database.scopeAccount('b');
    await first;
    expect(database.scopeReady, isFalse);
    await second;
    expect(database.scopeReady, isTrue);
    expect(await LocalMetaStore(database.db).lastUserId(), 'b');
  });
}
