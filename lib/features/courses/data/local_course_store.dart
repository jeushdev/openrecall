import 'package:sqflite/sqflite.dart';

import '../domain/course.dart';

/// DAO for the `offline_courses` table (engine-v2-spec §5) — a read-only mirror
/// of the user's courses so the Deck Library can group decks by course while
/// offline. There is no `is_synced` column: course assignment is online-only,
/// so nothing here is ever pushed back.
///
/// As with [LocalDeckStore], a `null` database makes every read return empty
/// and every write a no-op, so a cache-first repository wrapping this store
/// behaves like the plain Supabase one.
class LocalCourseStore {
  LocalCourseStore(this._db);

  final Database? _db;

  bool get isNoop => _db == null;

  /// Replaces the local mirror with [remote]. Called after every successful
  /// online course-list fetch. Courses are few and never edited locally, so a
  /// full replace is simplest and cannot lose local state.
  Future<void> refreshCourses(List<Course> remote) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('offline_courses');
      for (final c in remote) {
        await txn.insert('offline_courses', _values(c));
      }
    });
  }

  /// The mirrored courses, for when the online fetch failed.
  Future<List<Course>> cachedCourses() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_courses', orderBy: 'name');
    return rows.map(_fromRow).toList();
  }

  Map<String, Object?> _values(Course c) => {
        'id': c.id,
        'name': c.name,
        'accent_color': c.accentColor,
        'is_default': c.isDefault ? 1 : 0,
      };

  /// The mirror only carries the columns the Library needs; the fields it does
  /// not store are filled with neutral placeholders.
  Course _fromRow(Map<String, Object?> r) => Course(
        id: r['id'] as String,
        userId: '',
        name: r['name'] as String,
        accentColor: r['accent_color'] as String,
        isDefault: (r['is_default'] as int) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}
