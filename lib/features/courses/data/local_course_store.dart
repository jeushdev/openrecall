import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/stale_account_scope.dart';

import '../../../core/local_db/local_deletion.dart';
import '../domain/course.dart';

/// A course row with an unsynced local edit waiting to go up to Supabase,
/// together with [baseUpdatedAt] — the Supabase `updated_at` last seen for it
/// (null when the course was created offline and has never synced).
class DirtyCourse {
  DirtyCourse({
    required this.id,
    required this.userId,
    required this.name,
    required this.accentColor,
    required this.isDefault,
    required this.updatedAt,
    required this.baseUpdatedAt,
    required this.position,
  });

  final String id;
  final String? userId;
  final String name;
  final String accentColor;
  final bool isDefault;
  final DateTime updatedAt;
  final DateTime? baseUpdatedAt;

  /// The row's `position` — client-authoritative after an offline drag, pushed
  /// via `set_course_positions` on reconnect (milestone E3).
  final int position;

  /// True when this row has never reached Supabase — created offline, not yet
  /// pushed. Its sync push is an insert, and a delete before that push needs no
  /// remote call.
  bool get createdLocally => baseUpdatedAt == null;
}

/// DAO for the `offline_courses` table.
///
/// Since spec-v4 courses are editable offline: a local create / rename /
/// re-colour sets `is_synced = 0`, and [SyncService] pushes those rows on
/// reconnect. A `null` database (the default outside `main()`) makes every read
/// return empty and every write a no-op, so a cache-first repository wrapping
/// this store behaves like the plain Supabase one.
class LocalCourseStore {
  LocalCourseStore(this._database, {this.isCurrent});

  final Database? _database;
  final bool Function()? isCurrent;
  Database? get _db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

  bool get isNoop => _db == null;

  Future<bool> hasFetchedCourses() async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query(
      'application_cache',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: ['courses'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---- read-through refresh -------------------------------------------------

  /// Merges [remote] into the mirror after a successful online fetch, without
  /// clobbering rows that still hold an unsynced local edit. Synced local rows
  /// that no longer exist remotely are dropped; unsynced ones are always kept.
  Future<void> refreshCourses(List<Course> remote) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final dirtyIds = {
        for (final r in await txn.query(
          'offline_courses',
          columns: ['id'],
          where: 'is_synced = 0',
        ))
          r['id'] as String,
      };
      final tombstonedIds = {
        for (final r in await txn.query(
          'offline_deletions',
          columns: ['entity_id'],
          where: "entity_type = 'course'",
        ))
          r['entity_id'] as String,
      };
      final remoteIds = {for (final c in remote) c.id};
      const retainPendingDecks =
          'id IN (SELECT course_id FROM offline_decks WHERE is_synced = 0)';
      if (remoteIds.isEmpty) {
        await txn.delete(
          'offline_courses',
          where: 'is_synced = 1 AND NOT ($retainPendingDecks)',
        );
      } else {
        await txn.delete(
          'offline_courses',
          where:
              'is_synced = 1 AND id NOT IN '
              "(${List.filled(remoteIds.length, '?').join(',')}) "
              'AND NOT ($retainPendingDecks)',
          whereArgs: remoteIds.toList(),
        );
      }
      for (final c in remote) {
        if (dirtyIds.contains(c.id) || tombstonedIds.contains(c.id)) continue;
        await txn.insert(
          'offline_courses',
          _syncedValues(c),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert('application_cache', {
        'key': 'courses',
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
        'coverage': 'complete',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// The mirrored courses, for when the online fetch failed.
  Future<List<Course>> cachedCourses() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_courses', orderBy: 'position, name');
    return rows.map(_fromRow).toList();
  }

  Future<void> saveRemoteCourse(Course course) async {
    final db = _db;
    if (db == null) return;
    final tombstone = await db.query(
      'offline_deletions',
      columns: ['entity_id'],
      where: "entity_type = 'course' AND entity_id = ?",
      whereArgs: [course.id],
      limit: 1,
    );
    if (tombstone.isNotEmpty) return;
    final dirty = await db.query(
      'offline_courses',
      columns: ['id'],
      where: 'id = ? AND is_synced = 0',
      whereArgs: [course.id],
      limit: 1,
    );
    if (dirty.isNotEmpty) return;
    await db.insert(
      'offline_courses',
      _syncedValues(course),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeRemoteCourse(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(
      'offline_courses',
      where: 'id = ? AND is_synced = 1',
      whereArgs: [id],
    );
  }

  /// Applies a manual course reorder made offline: stamps each id's list index
  /// as its `position` and marks the row `is_synced = 0` so [SyncService]
  /// pushes the new order via `set_course_positions` on reconnect (milestone
  /// E3). Ids not in the mirror are skipped.
  Future<void> reorderCourses(List<String> orderedIds) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final (i, id) in orderedIds.indexed) {
        await txn.update(
          'offline_courses',
          {'position': i, 'is_synced': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// The id of the user's default course, or `null` when the mirror has none —
  /// used to resolve a null `course_id` on an offline deck create, matching the
  /// server `decks_fill_default_course` trigger.
  Future<String?> defaultCourseId() async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'offline_courses',
      columns: ['id'],
      where: 'is_default = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  // ---- offline writes ------------------------------------------------------

  /// Inserts a course created offline. The caller generates [id] up front so the
  /// row is permanent from creation (spec-v4).
  Future<Course> createCourse({
    required String id,
    required String? userId,
    required String name,
    required String accentColor,
  }) async {
    final now = DateTime.now().toUtc();
    final course = Course(
      id: id,
      userId: userId ?? '',
      name: name,
      accentColor: accentColor,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    );
    final db = _db;
    if (db == null) return course;
    await db.insert('offline_courses', {
      ..._syncedValues(course),
      'base_updated_at': null,
      'is_synced': 0,
    });
    return course;
  }

  /// Applies an offline rename / re-colour and marks the row unsynced. Returns
  /// the updated course, or `null` if the row is not in the mirror.
  Future<Course?> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) async {
    final db = _db;
    if (db == null) return null;
    final existing = await _rowById(id);
    if (existing == null) return null;
    final now = DateTime.now().toUtc();
    await db.update(
      'offline_courses',
      {
        'name': ?name,
        'accent_color': ?accentColor,
        'updated_at': now.toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return _fromRow({...existing, 'updated_at': now.toIso8601String()});
  }

  /// Removes a course offline: its decks are re-homed to [defaultCourseId]
  /// (and marked unsynced, matching the remote two-statement delete), a
  /// tombstone is written, and the course row is dropped.
  Future<void> deleteCourse(
    String id, {
    required String defaultCourseId,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final row = await txn.query(
        'offline_courses',
        columns: ['base_updated_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final createdLocally =
          row.isEmpty || row.first['base_updated_at'] == null;

      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'offline_decks',
        {'course_id': defaultCourseId, 'updated_at': now, 'is_synced': 0},
        where: 'course_id = ?',
        whereArgs: [id],
      );
      await txn.insert('offline_deletions', {
        'entity_type': 'course',
        'entity_id': id,
        'deck_id': null,
        'created_locally': createdLocally ? 1 : 0,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('offline_courses', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---- sync support -------------------------------------------------------

  Future<List<DirtyCourse>> unsyncedCourses() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_courses', where: 'is_synced = 0');
    return rows.map(_dirtyFromRow).toList();
  }

  Future<void> markCourseSynced(String id, DateTime remoteUpdatedAt) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_courses',
      {'updated_at': iso, 'base_updated_at': iso, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalDeletion>> courseDeletions() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_deletions',
      where: 'entity_type = ?',
      whereArgs: ['course'],
    );
    return rows.map(_deletionFromRow).toList();
  }

  Future<void> clearCourseDeletion(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(
      'offline_deletions',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: ['course', id],
    );
  }

  // ---- mapping ----------------------------------------------------------------

  Future<Map<String, Object?>?> _rowById(String id) async {
    final rows = await _db!.query(
      'offline_courses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Column values for a row pulled from Supabase — synced, with the compare-
  /// and-set base pinned to the remote `updated_at`.
  Map<String, Object?> _syncedValues(Course c) => {
    'id': c.id,
    'name': c.name,
    'accent_color': c.accentColor,
    'is_default': c.isDefault ? 1 : 0,
    'user_id': c.userId.isEmpty ? null : c.userId,
    'created_at': c.createdAt.toUtc().toIso8601String(),
    'updated_at': c.updatedAt.toUtc().toIso8601String(),
    'base_updated_at': c.updatedAt.toUtc().toIso8601String(),
    'is_synced': 1,
  };

  Course _fromRow(Map<String, Object?> r) => Course(
    id: r['id'] as String,
    userId: (r['user_id'] as String?) ?? '',
    name: r['name'] as String,
    accentColor: r['accent_color'] as String,
    isDefault: (r['is_default'] as int) == 1,
    createdAt: _parseOrEpoch(r['created_at']),
    updatedAt: _parseOrEpoch(r['updated_at']),
    position: (r['position'] as int?) ?? 0,
  );

  DirtyCourse _dirtyFromRow(Map<String, Object?> r) => DirtyCourse(
    id: r['id'] as String,
    userId: r['user_id'] as String?,
    name: r['name'] as String,
    accentColor: r['accent_color'] as String,
    isDefault: (r['is_default'] as int) == 1,
    updatedAt: _parseOrEpoch(r['updated_at']),
    baseUpdatedAt: (r['base_updated_at'] as String?) == null
        ? null
        : DateTime.parse(r['base_updated_at'] as String),
    position: (r['position'] as int?) ?? 0,
  );

  LocalDeletion _deletionFromRow(Map<String, Object?> r) => LocalDeletion(
    entityType: r['entity_type'] as String,
    entityId: r['entity_id'] as String,
    deckId: r['deck_id'] as String?,
    createdLocally: (r['created_locally'] as int) == 1,
  );

  static DateTime _parseOrEpoch(Object? value) => value == null
      ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
      : DateTime.parse(value as String);
}
