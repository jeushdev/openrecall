import 'package:sqflite/sqflite.dart';

import '../../features/profile/domain/profile.dart';
import 'stale_account_scope.dart';

enum CacheCoverage { partial, complete }

typedef CacheMetadata = ({DateTime fetchedAt, CacheCoverage coverage});

/// Small application metadata in the same database as downloaded decks.
class ApplicationCache {
  ApplicationCache(this._database, {this.isCurrent});
  final Database? _database;
  final bool Function()? isCurrent;
  Database? get db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

  bool get isAvailable => db != null;

  Future<CacheMetadata?> metadata(String key) async {
    final rows = await db?.query(
      'application_cache',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows == null || rows.isEmpty) return null;
    return (
      fetchedAt: DateTime.parse(rows.single['fetched_at'] as String),
      coverage: CacheCoverage.values.byName(rows.single['coverage'] as String),
    );
  }

  Future<bool> wasFetched(String key) async =>
      (await db?.query(
        'application_cache',
        where: 'key = ?',
        whereArgs: [key],
      ))?.isNotEmpty ??
      false;

  Future<void> markFetched(
    String key, {
    CacheCoverage coverage = CacheCoverage.complete,
  }) async {
    await db?.insert('application_cache', {
      'key': key,
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
      'coverage': coverage.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Profile?> profile() async {
    final rows = await db?.query('cached_profile');
    if (rows == null || rows.isEmpty) return null;
    final row = rows.single;
    return (
      id: row['id'] as String,
      email: row['email'] as String,
      username: row['username'] as String?,
    );
  }

  Future<void> saveProfile(Profile? profile) async {
    final database = db;
    if (database == null) return;
    await database.transaction((txn) async {
      await txn.delete('cached_profile');
      if (profile != null) {
        await txn.insert('cached_profile', {
          'id': profile.id,
          'email': profile.email,
          'username': profile.username,
        });
      }
    });
  }
}
