import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/stale_account_scope.dart';

import '../../../core/local_db/local_deletion.dart';
import '../../courses/domain/course.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/offline_download.dart';

/// A card row that has an unsynced local mastery/fail edit waiting to go up to
/// Supabase, together with [baseUpdatedAt] — the Supabase `updated_at` last seen
/// for it, which the sync pass uses as its compare-and-set target.
class DirtyCard {
  DirtyCard({
    required this.id,
    required this.deckId,
    required this.masteryLevel,
    required this.failCount,
    required this.updatedAt,
    required this.baseUpdatedAt,
  });

  final String id;
  final String deckId;
  final int masteryLevel;
  final int failCount;
  final DateTime updatedAt;
  final DateTime baseUpdatedAt;
}

/// A deck row with an unsynced local edit (created / renamed / re-coursed
/// offline) waiting to go up to Supabase (spec-v4).
class DirtyDeck {
  DirtyDeck({
    required this.id,
    required this.name,
    required this.courseId,
    required this.lastStudiedAt,
    required this.updatedAt,
    required this.baseUpdatedAt,
    required this.position,
  });

  final String id;
  final String name;
  final String? courseId;
  final DateTime? lastStudiedAt;
  final DateTime? updatedAt;
  final DateTime? baseUpdatedAt;

  /// The row's `position` — client-authoritative after an offline drag, pushed
  /// via `set_deck_positions` on reconnect (milestone E3).
  final int position;

  /// True when this row has never reached Supabase — created offline, not yet
  /// pushed.
  bool get createdLocally => baseUpdatedAt == null;
}

/// DAO for the `offline_decks` / `offline_cards` tables.
///
/// A deck has a row in `offline_decks` exactly when it is cached — either
/// because it was opened online (auto-cached) or because the user pinned it
/// "available offline" (`is_pinned = 1`, never auto-evicted). Since spec-v4
/// decks and cards are editable offline: a local create / rename / re-course /
/// card add / card edit sets `is_synced = 0` (and, for card content,
/// `content_dirty = 1`), and [SyncService] walks those rows on reconnect.
///
/// When [_db] is `null` (no local database — the default outside `main()`),
/// every read returns empty and every write is a no-op, so a cache-first
/// repository wrapping this store behaves like the plain Supabase one.
class LocalDeckStore {
  LocalDeckStore(this._database, {this.isCurrent});

  final Database? _database;
  final bool Function()? isCurrent;
  Database? get _db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

  /// True when there is no local database, so nothing can be cached or synced.
  bool get isNoop => _db == null;

  /// Rechecked inside guarded package transactions so an account switch that
  /// happens while SQLite work is queued cannot commit through an old handle.
  bool get isScopeCurrent => isCurrent?.call() ?? true;

  /// A pending local re-course is authoritative over fetched deck metadata.
  Future<String?> locallyAuthoritativeCourseId(String deckId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'offline_decks',
      columns: ['course_id'],
      where: 'id = ? AND is_synced = 0',
      whereArgs: [deckId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['course_id'] as String?;
  }

  Future<bool> hasCourseMetadata(String courseId) async {
    final db = _db;
    if (db == null) return false;
    return (await db.query(
      'offline_courses',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [courseId],
      limit: 1,
    )).isNotEmpty;
  }

  Future<bool> hasFetchedDeckMetadata() async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query(
      'application_cache',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: ['decks'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---- membership --------------------------------------------------------

  /// The ids of every deck with a verified complete card package.
  ///
  /// Kept for compatibility with older callers; row existence is deliberately
  /// not treated as a download because every listed deck has a metadata row.
  Future<Set<String>> downloadedDeckIds() async {
    return completeCardDeckIds();
  }

  /// The ids of decks the user pinned "available offline" (`is_pinned = 1`).
  Future<Set<String>> pinnedDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db.query(
      'offline_decks',
      columns: ['id'],
      where: 'is_pinned = 1 AND cards_complete = 1',
    );
    return {for (final r in rows) r['id'] as String};
  }

  Future<bool> isDownloaded(String deckId) async {
    return isCardSetComplete(deckId);
  }

  /// The ids of decks whose full card set was verified by a successful fetch.
  ///
  /// `refreshDeckMeta` writes an `offline_decks` header row for every listed
  /// deck, long before any card set is mirrored. Row existence means "listed";
  /// a row here means "studiable".
  Future<Set<String>> completeCardDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db.query(
      'offline_decks',
      columns: ['id'],
      where: 'cards_complete = 1',
    );
    return {for (final r in rows) r['id'] as String};
  }

  /// Whether [deckId] has a verified complete card set. This remains true for
  /// a verified empty deck, while metadata-only and migrated legacy rows stay
  /// false until an online fetch succeeds.
  Future<bool> isCardSetComplete(String deckId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query(
      'offline_decks',
      columns: ['id'],
      where: 'id = ? AND cards_complete = 1',
      whereArgs: [deckId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// The complete persisted package contract for one deck. Unlike provider
  /// operation state, this survives process restart.
  Future<OfflinePackageStatus> packageStatus(String deckId) async {
    final db = _db;
    if (db == null) return OfflinePackageStatus.missing(deckId);
    final rows = await db.query(
      'offline_decks',
      columns: [
        'is_pinned',
        'cards_complete',
        'cache_suppressed',
        'remote_missing',
        'downloaded_at',
      ],
      where: 'id = ?',
      whereArgs: [deckId],
      limit: 1,
    );
    if (rows.isEmpty) return OfflinePackageStatus.missing(deckId);
    final row = rows.single;
    return OfflinePackageStatus(
      deckId: deckId,
      hasLocalMetadata: true,
      isPinned: (row['is_pinned'] as int? ?? 0) == 1,
      cardsComplete: (row['cards_complete'] as int? ?? 0) == 1,
      cacheSuppressed: (row['cache_suppressed'] as int? ?? 0) == 1,
      remoteMissing: (row['remote_missing'] as int? ?? 0) == 1,
      downloadedAt: _parseNullable(row['downloaded_at']),
    );
  }

  /// Stores only a confirmed targeted remote result. Callers must not use an
  /// absent row in an account-wide list as proof of remote deletion.
  Future<void> setRemoteMissing(String deckId, {required bool missing}) async {
    await setRemoteMissingGuarded(deckId, missing: missing);
  }

  /// Applies targeted remote-presence evidence only while [operation] still
  /// owns the deck. Returns whether the persisted flag actually changed.
  Future<bool> setRemoteMissingGuarded(
    String deckId, {
    required bool missing,
    OfflinePackageOperation? operation,
    bool Function(OfflinePackageOperation operation)? isOperationCurrent,
  }) async {
    final db = _db;
    if (db == null) return false;
    return db.transaction((txn) async {
      _checkOperation(operation, isOperationCurrent);
      final changed = await txn.update(
        'offline_decks',
        {'remote_missing': missing ? 1 : 0},
        where: 'id = ? AND remote_missing != ?',
        whereArgs: [deckId, missing ? 1 : 0],
      );
      _checkOperation(operation, isOperationCurrent);
      return changed > 0;
    });
  }

  Future<Set<String>> confirmedMissingDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db.query(
      'offline_decks',
      columns: ['id'],
      where: 'remote_missing = 1',
    );
    return {for (final row in rows) row['id'] as String};
  }

  // ---- download / remove --------------------------------------------------

  /// Marks [deckId] pinned "available offline" and refreshes its cached header.
  /// **Does not touch the card mirror** — the caller mirrors cards separately via
  /// [mirrorCards], which skips `is_synced = 0` rows, so an unsynced offline card
  /// edit is never clobbered. (The old `downloadDeck` replaced the whole card
  /// set, silently discarding local edits.)
  Future<void> pinDeck({
    required String deckId,
    required String name,
    String? courseId,
  }) async {
    final db = _db;
    if (db == null) return;
    final exists = (await db.query(
      'offline_decks',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [deckId],
      limit: 1,
    )).isNotEmpty;
    if (exists) {
      await db.update(
        'offline_decks',
        {
          'name': name,
          'course_id': ?courseId,
          'is_pinned': 1,
          'cache_suppressed': 0,
        },
        where: 'id = ?',
        whereArgs: [deckId],
      );
    } else {
      await db.insert('offline_decks', {
        'id': deckId,
        'name': name,
        'course_id': ?courseId,
        'is_pinned': 1,
        'cache_suppressed': 0,
        'is_synced': 1,
      });
    }
  }

  /// Unpins a deck without deleting application history. Clean package cards
  /// are discarded, except cards referenced by an active session or pending
  /// local queue work. Dirty cards and deletion tombstones are always retained.
  Future<void> removeDeck(
    String deckId, {
    OfflinePackageOperation? operation,
    bool Function(OfflinePackageOperation operation)? isOperationCurrent,
    bool Function(String deckId)? hasStartupLease,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      _checkOperation(operation, isOperationCurrent);
      if (hasStartupLease?.call(deckId) == true) {
        throw OfflinePackageActiveSessionException(deckId);
      }
      if (await _hasActiveSession(txn, deckId)) {
        throw OfflinePackageActiveSessionException(deckId);
      }
      _checkOperation(operation, isOperationCurrent);
      if (hasStartupLease?.call(deckId) == true) {
        throw OfflinePackageActiveSessionException(deckId);
      }
      await txn.update(
        'offline_decks',
        {
          'is_pinned': 0,
          'cards_complete': 0,
          'downloaded_at': null,
          'cache_suppressed': 1,
        },
        where: 'id = ?',
        whereArgs: [deckId],
      );
      await txn.update(
        'offline_cards',
        {'in_current_package': 0},
        where: 'deck_id = ?',
        whereArgs: [deckId],
      );
      await txn.delete(
        'offline_cards',
        where: '''
          deck_id = ? AND is_synced = 1 AND id NOT IN (
            SELECT sc.card_id
            FROM offline_session_cards sc
            JOIN offline_study_sessions s ON s.id = sc.session_id
            WHERE s.deck_id = ? AND (
              s.status = 'active' OR s.is_synced = 0 OR sc.is_synced = 0
            )
          )
        ''',
        whereArgs: [deckId, deckId],
      );
    });
  }

  Future<bool> hasActiveSession(String deckId) async {
    final db = _db;
    if (db == null) return false;
    return _hasActiveSession(db, deckId);
  }

  Future<bool> _hasActiveSession(DatabaseExecutor txn, String deckId) async {
    final rows = await txn.query(
      'offline_study_sessions',
      columns: ['id'],
      where: "deck_id = ? AND status = 'active'",
      whereArgs: [deckId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Whether this deck still holds local work that hasn't reached Supabase — an
  /// offline rename / re-course, an offline-authored or -edited card, or an
  /// offline session. Used by the "Keep available offline" toggle to decide
  /// whether unpinning would lose anything (spec-v4 §O4).
  Future<bool> deckHasUnsyncedWork(String deckId) async {
    final db = _db;
    if (db == null) return false;
    return _deckHasUnsyncedWork(db, deckId);
  }

  Future<bool> _deckHasUnsyncedWork(DatabaseExecutor txn, String deckId) async {
    final deck = await txn.query(
      'offline_decks',
      columns: ['is_synced'],
      where: 'id = ?',
      whereArgs: [deckId],
      limit: 1,
    );
    if (deck.isNotEmpty && (deck.first['is_synced'] as int) == 0) return true;
    final card = await txn.query(
      'offline_cards',
      columns: ['id'],
      where: 'deck_id = ? AND is_synced = 0',
      whereArgs: [deckId],
      limit: 1,
    );
    if (card.isNotEmpty) return true;
    final session = await txn.query(
      'offline_study_sessions',
      columns: ['id'],
      where: 'deck_id = ? AND is_synced = 0',
      whereArgs: [deckId],
      limit: 1,
    );
    if (session.isNotEmpty) return true;
    final queue = await txn.rawQuery(
      '''
      SELECT sc.id
      FROM offline_session_cards sc
      JOIN offline_study_sessions s ON s.id = sc.session_id
      WHERE s.deck_id = ? AND sc.is_synced = 0
      LIMIT 1
      ''',
      [deckId],
    );
    if (queue.isNotEmpty) return true;
    final tombstone = await txn.query(
      'offline_deletions',
      columns: ['entity_id'],
      where:
          "(entity_type = 'deck' AND entity_id = ?) OR "
          "(entity_type = 'card' AND deck_id = ?)",
      whereArgs: [deckId, deckId],
      limit: 1,
    );
    return tombstone.isNotEmpty;
  }

  // ---- read-through refresh ---------------------------------------------------

  /// Upserts every deck in a successful online deck-list fetch into the mirror,
  /// so the whole Library is browsable offline. Rows with an unsynced local edit
  /// are left untouched; synced rows absent from [remote] are dropped (deleted
  /// elsewhere). Card mirrors are not touched here — a deck's cards are mirrored
  /// when it is opened or pinned.
  Future<void> refreshDeckMeta(List<DeckSummary> remote) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final dirtyIds = {
        for (final r in await txn.query(
          'offline_decks',
          columns: ['id'],
          where: 'is_synced = 0',
        ))
          r['id'] as String,
      };
      final tombstonedIds = {
        for (final r in await txn.query(
          'offline_deletions',
          columns: ['entity_id'],
          where: "entity_type = 'deck'",
        ))
          r['entity_id'] as String,
      };
      final remoteIds = {for (final d in remote) d.id};
      const retainPendingWork =
          'is_pinned = 1 OR cache_suppressed = 1 OR remote_missing = 1 OR '
          'id IN (SELECT deck_id FROM offline_cards WHERE is_synced = 0) OR '
          'id IN (SELECT deck_id FROM offline_study_sessions '
          "WHERE is_synced = 0 OR status = 'active') OR "
          'id IN (SELECT s.deck_id FROM offline_session_cards sc '
          'JOIN offline_study_sessions s ON s.id = sc.session_id '
          'WHERE sc.is_synced = 0) OR '
          "id IN (SELECT entity_id FROM offline_deletions "
          "WHERE entity_type = 'deck') OR "
          "id IN (SELECT deck_id FROM offline_deletions "
          "WHERE entity_type = 'card')";
      if (remoteIds.isEmpty) {
        await txn.delete(
          'offline_decks',
          where: 'is_synced = 1 AND NOT ($retainPendingWork)',
        );
      } else {
        await txn.delete(
          'offline_decks',
          where:
              'is_synced = 1 AND id NOT IN '
              "(${List.filled(remoteIds.length, '?').join(',')}) "
              'AND NOT ($retainPendingWork)',
          whereArgs: remoteIds.toList(),
        );
      }
      await txn.delete(
        'offline_cards',
        where: '''
          deck_id NOT IN (SELECT id FROM offline_decks)
          AND is_synced = 1
          AND content_dirty = 0
          AND id NOT IN (
            SELECT entity_id FROM offline_deletions
            WHERE entity_type = 'card'
          )
          AND id NOT IN (
            SELECT sc.card_id
            FROM offline_session_cards sc
            JOIN offline_study_sessions s ON s.id = sc.session_id
            WHERE s.status = 'active' OR s.is_synced = 0 OR sc.is_synced = 0
          )
        ''',
      );
      for (final d in remote) {
        if (dirtyIds.contains(d.id) || tombstonedIds.contains(d.id)) continue;
        final exists = (await txn.query(
          'offline_decks',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [d.id],
          limit: 1,
        )).isNotEmpty;
        final meta = {
          'name': d.name,
          'course_id': d.courseId,
          'last_studied_at': d.lastStudiedAt?.toUtc().toIso8601String(),
          'mastery_level_sum': d.masteryLevelSum,
          'total_cards': d.totalCards,
          'is_synced': 1,
        };
        if (exists) {
          await txn.update(
            'offline_decks',
            meta,
            where: 'id = ?',
            whereArgs: [d.id],
          );
        } else {
          await txn.insert('offline_decks', {'id': d.id, ...meta});
        }
      }
      await txn.insert('application_cache', {
        'key': 'decks',
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
        'coverage': 'complete',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Caches metadata returned by a successful create or edit without waiting
  /// for the next list refresh. Existing card coverage and pin state stay put.
  Future<void> saveRemoteDeck(Deck deck) async {
    final db = _db;
    if (db == null) return;
    final values = {
      'name': deck.name,
      'course_id': deck.courseId,
      'last_studied_at': deck.lastStudiedAt?.toUtc().toIso8601String(),
      'created_at': deck.createdAt.toUtc().toIso8601String(),
      'updated_at': deck.updatedAt.toUtc().toIso8601String(),
      'base_updated_at': deck.updatedAt.toUtc().toIso8601String(),
      'is_synced': 1,
    };
    final updated = await db.update(
      'offline_decks',
      values,
      where: 'id = ? AND is_synced = 1',
      whereArgs: [deck.id],
    );
    if (updated == 0) {
      final dirty = await db.query(
        'offline_decks',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [deck.id],
        limit: 1,
      );
      final tombstone = await db.query(
        'offline_deletions',
        columns: ['entity_id'],
        where: "entity_type = 'deck' AND entity_id = ?",
        whereArgs: [deck.id],
        limit: 1,
      );
      if (dirty.isEmpty && tombstone.isEmpty) {
        await db.insert('offline_decks', {'id': deck.id, ...values});
      }
    }
  }

  Future<void> removeRemoteDeck(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(
      'offline_decks',
      where: 'id = ? AND is_synced = 1',
      whereArgs: [id],
    );
  }

  /// Refreshes a deck's card mirror from a successful online fetch, without
  /// clobbering rows that still hold an unsynced local edit. Ensures the
  /// `offline_decks` row exists, so opening any deck online auto-caches it
  /// (unpinned).
  Future<void> mirrorCards(String deckId, List<FlashCard> remote) async {
    await commitDeckPackage(deckId: deckId, cards: remote);
  }

  /// Atomically installs a fully validated package. When [pin] is non-null the
  /// pin preference changes in the same transaction as card replacement and
  /// the completeness marker, so a failed insert leaves the previous package
  /// and pin state intact.
  Future<void> commitDeckPackage({
    required String deckId,
    required List<FlashCard> cards,
    String? deckName,
    String? courseId,
    Deck? deck,
    List<Course> courses = const [],
    bool? pin,
    OfflinePackageOperation? operation,
    bool Function(OfflinePackageOperation operation)? isOperationCurrent,
    bool Function(String deckId)? hasStartupLease,
  }) async {
    final db = _db;
    if (db == null) return;
    if (deck != null && (deck.id != deckId || deck.courseId == null)) {
      throw StateError('Invalid deck metadata for $deckId');
    }
    _validateCompletePackage(deckId, cards);
    await db.transaction((txn) async {
      _checkOperation(operation, isOperationCurrent);
      if (operation?.kind == OfflinePackageOperationKind.refresh) {
        if (hasStartupLease?.call(deckId) == true ||
            await _hasActiveSession(txn, deckId)) {
          throw OfflinePackageActiveSessionException(deckId);
        }
      }
      final suppressionRows = await txn.query(
        'offline_decks',
        columns: ['cache_suppressed'],
        where: 'id = ?',
        whereArgs: [deckId],
        limit: 1,
      );
      if (suppressionRows.isNotEmpty &&
          (suppressionRows.single['cache_suppressed'] as int? ?? 0) == 1 &&
          pin != true) {
        return;
      }
      if (operation?.kind == OfflinePackageOperationKind.refresh &&
          hasStartupLease?.call(deckId) == true) {
        throw OfflinePackageActiveSessionException(deckId);
      }
      for (final course in courses) {
        if (course.id.isEmpty ||
            course.name.trim().isEmpty ||
            course.accentColor.trim().isEmpty) {
          throw StateError('Invalid course metadata for $deckId');
        }
        final deleted = await txn.query(
          'offline_deletions',
          columns: ['entity_id'],
          where: "entity_type = 'course' AND entity_id = ?",
          whereArgs: [course.id],
          limit: 1,
        );
        if (deleted.isNotEmpty) continue;
        final values = <String, Object?>{
          'id': course.id,
          'user_id': course.userId.isEmpty ? null : course.userId,
          'name': course.name,
          'accent_color': course.accentColor,
          'is_default': course.isDefault ? 1 : 0,
          'position': course.position,
          'created_at': course.createdAt.toUtc().toIso8601String(),
          'updated_at': course.updatedAt.toUtc().toIso8601String(),
          'base_updated_at': course.updatedAt.toUtc().toIso8601String(),
          'is_synced': 1,
        };
        final changed = await txn.update(
          'offline_courses',
          values,
          where: 'id = ? AND is_synced = 1',
          whereArgs: [course.id],
        );
        if (changed == 0) {
          final existingCourse = await txn.query(
            'offline_courses',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [course.id],
            limit: 1,
          );
          if (existingCourse.isEmpty) {
            await txn.insert('offline_courses', values);
          }
        }
      }
      final existingRows = await txn.query(
        'offline_decks',
        columns: ['id', 'cache_suppressed'],
        where: 'id = ?',
        whereArgs: [deckId],
        limit: 1,
      );
      final exists = existingRows.isNotEmpty;
      final suppressed =
          exists && (existingRows.single['cache_suppressed'] as int? ?? 0) == 1;
      // Incidental read-through caching may display remote rows, but cannot
      // recreate a package the user intentionally removed. An explicit
      // download (pin == true) is the only M1 path that clears suppression.
      if (suppressed && pin != true) return;
      if (!exists) {
        final remote = deck;
        await txn.insert('offline_decks', {
          'id': deckId,
          'name': remote?.name ?? deckName ?? '',
          'course_id': remote?.courseId ?? courseId,
          if (remote != null) ...{
            'position': remote.position,
            'last_studied_at': remote.lastStudiedAt?.toUtc().toIso8601String(),
            'created_at': remote.createdAt.toUtc().toIso8601String(),
            'updated_at': remote.updatedAt.toUtc().toIso8601String(),
            'base_updated_at': remote.updatedAt.toUtc().toIso8601String(),
          },
          'is_synced': 1,
        });
      } else if (deck != null || deckName != null) {
        final remote = deck;
        await txn.update(
          'offline_decks',
          {
            'name': remote?.name ?? deckName,
            if (remote != null) ...{
              'course_id': remote.courseId,
              'position': remote.position,
              'last_studied_at': remote.lastStudiedAt
                  ?.toUtc()
                  .toIso8601String(),
              'created_at': remote.createdAt.toUtc().toIso8601String(),
              'updated_at': remote.updatedAt.toUtc().toIso8601String(),
              'base_updated_at': remote.updatedAt.toUtc().toIso8601String(),
            },
          },
          where: 'id = ? AND is_synced = 1',
          whereArgs: [deckId],
        );
      }
      final metadata = (await txn.query(
        'offline_decks',
        columns: ['name', 'course_id'],
        where: 'id = ?',
        whereArgs: [deckId],
        limit: 1,
      )).single;
      if ((metadata['name'] as String).trim().isEmpty) {
        throw StateError('Missing deck metadata for $deckId');
      }
      final packageCourseId = metadata['course_id'] as String?;
      if (packageCourseId != null) {
        final hasCourse = (await txn.query(
          'offline_courses',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [packageCourseId],
          limit: 1,
        )).isNotEmpty;
        if (!hasCourse) {
          throw StateError('Missing course metadata for $deckId');
        }
      }
      final dirtyIds = {
        for (final r in await txn.query(
          'offline_cards',
          columns: ['id'],
          where: 'deck_id = ? AND is_synced = 0',
          whereArgs: [deckId],
        ))
          r['id'] as String,
      };
      final tombstonedIds = {
        for (final r in await txn.query(
          'offline_deletions',
          columns: ['entity_id'],
          where: "entity_type = 'card' AND deck_id = ?",
          whereArgs: [deckId],
        ))
          r['entity_id'] as String,
      };
      const retainForSession = '''
        id IN (
          SELECT sc.card_id
          FROM offline_session_cards sc
          JOIN offline_study_sessions s ON s.id = sc.session_id
          WHERE s.deck_id = ? AND (
            s.status = 'active' OR s.is_synced = 0 OR sc.is_synced = 0
          )
        )
      ''';
      // Mark first, then install the fetched set. This avoids SQLite bind
      // limits for large packages and separates membership from retention.
      await txn.update(
        'offline_cards',
        {'in_current_package': 0},
        where: 'deck_id = ?',
        whereArgs: [deckId],
      );
      for (final c in cards) {
        if (tombstonedIds.contains(c.id)) continue;
        if (dirtyIds.contains(c.id)) {
          await txn.update(
            'offline_cards',
            {'in_current_package': 1},
            where: 'id = ?',
            whereArgs: [c.id],
          );
          continue;
        }
        await txn.insert('offline_cards', {
          ..._cardValues(c),
          'in_current_package': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.delete(
        'offline_cards',
        where:
            'deck_id = ? AND is_synced = 1 AND in_current_package = 0 '
            'AND NOT ($retainForSession)',
        whereArgs: [deckId, deckId],
      );
      _checkOperation(operation, isOperationCurrent);
      final effectiveRows = await txn.query(
        'offline_cards',
        columns: ['mastery_level'],
        where: 'deck_id = ? AND (in_current_package = 1 OR is_synced = 0)',
        whereArgs: [deckId],
      );
      final effectiveLevels = [
        for (final row in effectiveRows) row['mastery_level'] as int,
      ];
      _checkOperation(operation, isOperationCurrent);
      await txn.update(
        'offline_decks',
        {
          'cards_complete': 1,
          'downloaded_at': DateTime.now().toUtc().toIso8601String(),
          if (pin != null) 'is_pinned': pin ? 1 : 0,
          if (pin == true) 'cache_suppressed': 0,
          'remote_missing': 0,
          'total_cards': effectiveLevels.length,
          'mastery_level_sum': effectiveLevels.fold<int>(0, (a, b) => a + b),
        },
        where: 'id = ?',
        whereArgs: [deckId],
      );
      _checkOperation(operation, isOperationCurrent);
    });
  }

  void _checkOperation(
    OfflinePackageOperation? operation,
    bool Function(OfflinePackageOperation operation)? isOperationCurrent,
  ) {
    if (operation == null && isOperationCurrent == null) return;
    if (operation == null ||
        isOperationCurrent == null ||
        !isOperationCurrent(operation)) {
      throw OfflinePackageOperationSuperseded(operation?.deckId ?? 'unknown');
    }
  }

  void _validateCompletePackage(String deckId, List<FlashCard> cards) {
    final ids = <String>{};
    for (final card in cards) {
      if (card.id.isEmpty || card.deckId != deckId || !ids.add(card.id)) {
        throw StateError('Invalid card package for deck $deckId');
      }
      if (card.masteryLevel < 0 ||
          card.masteryLevel > masteredLevel ||
          card.failCount < 0) {
        throw StateError('Incomplete card metadata for ${card.id}');
      }
    }
  }

  // ---- offline reads --------------------------------------------------------

  /// Deck-Library summaries built entirely from the local mirror. Counts come
  /// from local cards only for verified complete sets; metadata-only and
  /// legacy-unverified sets retain the aggregate counts from [refreshDeckMeta].
  Future<List<DeckSummary>> cachedDeckSummaries() async {
    final db = _db;
    if (db == null) return const [];
    final decks = await db.query('offline_decks', orderBy: 'position, name');
    final result = <DeckSummary>[];
    for (final d in decks) {
      final id = d['id'] as String;
      final levels = [
        for (final r in await db.query(
          'offline_cards',
          columns: ['mastery_level'],
          where: 'deck_id = ? AND (in_current_package = 1 OR is_synced = 0)',
          whereArgs: [id],
        ))
          r['mastery_level'] as int,
      ];
      if ((d['cards_complete'] as int? ?? 0) == 1) {
        result.add(
          DeckSummary(
            id: id,
            name: d['name'] as String,
            courseId: d['course_id'] as String?,
            lastStudiedAt: _parseNullable(d['last_studied_at']),
            totalCards: levels.length,
            dueCards: levels.where((l) => l < masteredLevel).length,
            masteryPercent: masteryPercentFromLevels(levels),
            masteryLevelSum: levels.fold(0, (a, b) => a + b),
            position: (d['position'] as int?) ?? 0,
            createdAt: _parseNullable(d['created_at']),
          ),
        );
      } else {
        final total = (d['total_cards'] as int?) ?? 0;
        final sum = (d['mastery_level_sum'] as int?) ?? 0;
        result.add(
          DeckSummary(
            id: id,
            name: d['name'] as String,
            courseId: d['course_id'] as String?,
            lastStudiedAt: _parseNullable(d['last_studied_at']),
            totalCards: total,
            dueCards: total, // level-per-card unknown; treated as all due
            masteryPercent: masteryPercentFromLevelSum(sum, total),
            masteryLevelSum: sum,
            position: (d['position'] as int?) ?? 0,
            createdAt: _parseNullable(d['created_at']),
          ),
        );
      }
    }
    return result;
  }

  Future<List<FlashCard>> cards(String deckId) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_cards',
      where: 'deck_id = ? AND (in_current_package = 1 OR is_synced = 0)',
      whereArgs: [deckId],
      orderBy: 'created_at, id',
    );
    return rows.map(_cardFromRow).toList();
  }

  Future<FlashCard?> cardById(String id) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'offline_cards',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _cardFromRow(rows.first);
  }

  // ---- offline content writes -------------------------------------------------

  /// Inserts a deck created offline. The caller generates [id] up front.
  Future<void> createDeck({
    required String id,
    required String name,
    String? courseId,
  }) async {
    final db = _db;
    if (db == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('offline_decks', {
      'id': id,
      'name': name,
      'course_id': courseId,
      'created_at': now,
      'updated_at': now,
      'base_updated_at': null,
      'is_synced': 0,
      'is_pinned': 0,
    });
  }

  /// Applies an offline rename / re-course and marks the row unsynced.
  Future<void> updateDeck({
    required String id,
    String? name,
    String? courseId,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'offline_decks',
      {
        'name': ?name,
        'course_id': ?courseId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Applies a manual deck reorder made offline: stamps each id's list index as
  /// its `position` and marks the row `is_synced = 0` so [SyncService] pushes
  /// the new order via `set_deck_positions` on reconnect (milestone E3). Ids not
  /// in the mirror are skipped.
  Future<void> reorderDecks(List<String> orderedIds) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final (i, id) in orderedIds.indexed) {
        await txn.update(
          'offline_decks',
          {'position': i, 'is_synced': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  /// Removes a deck offline: writes a tombstone and drops the deck, its cards
  /// and its local sessions. Individual card tombstones are not written — the
  /// deck-level delete cascades server-side.
  Future<void> deleteDeck(String id) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final row = await txn.query(
        'offline_decks',
        columns: ['base_updated_at'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final createdLocally =
          row.isEmpty || row.first['base_updated_at'] == null;
      await _writeTombstone(txn, 'deck', id, createdLocally: createdLocally);
      // A card deleted-then-its-deck-deleted offline: the deck tombstone covers
      // it, so drop any stale card tombstones for this deck.
      final cardIds = [
        for (final r in await txn.query(
          'offline_cards',
          columns: ['id'],
          where: 'deck_id = ?',
          whereArgs: [id],
        ))
          r['id'] as String,
      ];
      for (final cid in cardIds) {
        await txn.delete(
          'offline_deletions',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['card', cid],
        );
      }
      final sessionIds = [
        for (final r in await txn.query(
          'offline_study_sessions',
          columns: ['id'],
          where: 'deck_id = ?',
          whereArgs: [id],
        ))
          r['id'] as String,
      ];
      for (final sid in sessionIds) {
        await txn.delete(
          'offline_session_cards',
          where: 'session_id = ?',
          whereArgs: [sid],
        );
      }
      await txn.delete(
        'offline_study_sessions',
        where: 'deck_id = ?',
        whereArgs: [id],
      );
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [id]);
      await txn.delete('offline_decks', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Inserts cards added / imported offline. The caller builds each [FlashCard]
  /// with a client-generated id; every row lands unsynced, content-dirty and
  /// `created_locally = 1`.
  ///
  /// `base_updated_at` keeps the non-null value [_cardValues] stamps: the column
  /// is `NOT NULL`, so nulling it here threw `SqliteException(1299)` on a real
  /// device (never caught before the milestone-E real-DB harness). "Never
  /// reached Supabase" is tracked by `created_locally` instead (milestone E3).
  Future<void> insertCards(List<FlashCard> cards) async {
    final db = _db;
    if (db == null) return;
    final deckIds = {for (final card in cards) card.deckId};
    final completeDeckIds = <String>{};
    for (final deckId in deckIds) {
      final rows = await db.query(
        'offline_decks',
        columns: ['id'],
        where: 'id = ? AND cards_complete = 1',
        whereArgs: [deckId],
        limit: 1,
      );
      if (rows.isNotEmpty) completeDeckIds.add(deckId);
    }
    final batch = db.batch();
    for (final c in cards) {
      batch.insert('offline_cards', {
        ..._cardValues(c),
        'is_synced': 0,
        'content_dirty': 1,
        'created_locally': 1,
        // Authored cards extend a verified package, but never manufacture
        // completeness for a partial/metadata-only deck.
        'in_current_package': completeDeckIds.contains(c.deckId) ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
  }

  /// Applies an offline edit to a card's content and marks it content-dirty.
  Future<void> updateCardContent({
    required String id,
    required String front,
    required String back,
    required List<String> keywords,
    required bool isConcept,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'offline_cards',
      {
        'front': front,
        'back': back,
        'keywords': jsonEncode(keywords),
        'is_concept': isConcept ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'is_synced': 0,
        'content_dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes a card offline: writes a tombstone and drops the local row. If the
  /// card was created offline and never synced, the tombstone is marked
  /// `created_locally` so the sync pass skips the remote delete.
  Future<void> deleteCard(String id) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final row = await txn.query(
        'offline_cards',
        columns: ['deck_id', 'created_locally'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (row.isEmpty) return;
      final createdLocally = (row.first['created_locally'] as int? ?? 0) == 1;
      await _writeTombstone(
        txn,
        'card',
        id,
        deckId: row.first['deck_id'] as String?,
        createdLocally: createdLocally,
      );
      await txn.delete('offline_cards', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ---- study-loop offline writes (mastery only) -----------------------------

  /// The offline counterpart of `updateCardMasteryGuarded`: applies a local
  /// mastery/fail write and marks the row unsynced. Honors the same
  /// compare-and-set contract — returns `null` if the local row's `updated_at`
  /// has moved since [expectedUpdatedAt].
  Future<FlashCard?> writeCardMasteryUnsynced({
    required String cardId,
    required int masteryLevel,
    required int failCount,
    required DateTime expectedUpdatedAt,
  }) async {
    final db = _db;
    if (db == null) return null;
    final existing = await cardById(cardId);
    if (existing == null) return null;
    if (existing.updatedAt.toUtc() != expectedUpdatedAt.toUtc()) return null;

    final now = DateTime.now().toUtc();
    await db.update(
      'offline_cards',
      {
        'mastery_level': masteryLevel,
        'fail_count': failCount,
        'updated_at': now.toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
    return FlashCard(
      id: existing.id,
      deckId: existing.deckId,
      front: existing.front,
      back: existing.back,
      keywords: existing.keywords,
      isConcept: existing.isConcept,
      masteryLevel: masteryLevel,
      failCount: failCount,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  /// Mirrors a confirmed Supabase mastery write into the local row and re-bases
  /// its compare-and-set target.
  Future<void> mirrorCardMastery(
    FlashCard row, {
    DateTime? expectedLocalUpdatedAt,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'offline_cards',
      {
        'mastery_level': row.masteryLevel,
        'fail_count': row.failCount,
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
        'base_updated_at': row.updatedAt.toUtc().toIso8601String(),
        'is_synced': 1,
      },
      where: expectedLocalUpdatedAt == null
          ? 'id = ?'
          : 'id = ? AND updated_at = ?',
      whereArgs: [
        row.id,
        if (expectedLocalUpdatedAt != null)
          expectedLocalUpdatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  /// Bumps a cached deck's last-studied stamp. Complete-package study starts
  /// mark the deck dirty so the existing deck upsert carries the stamp on the
  /// next background sync; online-only calls can mirror a confirmed stamp as
  /// already synced.
  Future<void> touchLastStudied(String deckId, {required bool synced}) async {
    final db = _db;
    if (db == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'offline_decks',
      {'last_studied_at': now, 'updated_at': now, 'is_synced': synced ? 1 : 0},
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  // ---- sync support -------------------------------------------------------

  /// Cards with a pending *mastery-only* edit (the guarded compare-and-set push
  /// path). New / content-edited cards are excluded — they go up via
  /// [contentDirtyCards] as a full upsert.
  Future<List<DirtyCard>> unsyncedCards() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_cards',
      where: 'is_synced = 0 AND content_dirty = 0',
    );
    return [
      for (final r in rows)
        DirtyCard(
          id: r['id'] as String,
          deckId: r['deck_id'] as String,
          masteryLevel: r['mastery_level'] as int,
          failCount: r['fail_count'] as int,
          updatedAt: DateTime.parse(r['updated_at'] as String),
          baseUpdatedAt: DateTime.parse(r['base_updated_at'] as String),
        ),
    ];
  }

  Future<void> markCardSynced(
    String id,
    DateTime remoteUpdatedAt, {
    DirtyCard? sentRevision,
  }) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_cards',
      {'updated_at': iso, 'base_updated_at': iso, 'is_synced': 1},
      where: sentRevision == null
          ? 'id = ?'
          : 'id = ? AND is_synced = 0 AND updated_at = ? '
                'AND mastery_level = ? AND fail_count = ?',
      whereArgs: [
        id,
        if (sentRevision != null) ...[
          sentRevision.updatedAt.toUtc().toIso8601String(),
          sentRevision.masteryLevel,
          sentRevision.failCount,
        ],
      ],
    );
  }

  /// Cards created or content-edited offline, as full rows for the upsert push.
  Future<List<FlashCard>> contentDirtyCards() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_cards', where: 'content_dirty = 1');
    return rows.map(_cardFromRow).toList();
  }

  Future<void> markCardContentSynced(
    String id,
    DateTime remoteUpdatedAt, {
    FlashCard? sentRevision,
  }) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_cards',
      {
        'updated_at': iso,
        'base_updated_at': iso,
        'is_synced': 1,
        'content_dirty': 0,
        // The row has now reached Supabase, so a later offline delete must do
        // the remote DELETE (milestone E3).
        'created_locally': 0,
      },
      where: sentRevision == null
          ? 'id = ?'
          : 'id = ? AND content_dirty = 1 AND updated_at = ? '
                'AND front = ? AND back = ? AND keywords = ? '
                'AND is_concept = ? AND mastery_level = ? AND fail_count = ?',
      whereArgs: [
        id,
        if (sentRevision != null) ...[
          sentRevision.updatedAt.toUtc().toIso8601String(),
          sentRevision.front,
          sentRevision.back,
          jsonEncode(sentRevision.keywords),
          sentRevision.isConcept ? 1 : 0,
          sentRevision.masteryLevel,
          sentRevision.failCount,
        ],
      ],
    );
  }

  Future<List<DirtyDeck>> unsyncedDecks() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_decks', where: 'is_synced = 0');
    return [
      for (final r in rows)
        DirtyDeck(
          id: r['id'] as String,
          name: r['name'] as String,
          courseId: r['course_id'] as String?,
          lastStudiedAt: _parseNullable(r['last_studied_at']),
          updatedAt: _parseNullable(r['updated_at']),
          baseUpdatedAt: (r['base_updated_at'] as String?) == null
              ? null
              : DateTime.parse(r['base_updated_at'] as String),
          position: (r['position'] as int?) ?? 0,
        ),
    ];
  }

  Future<void> markDeckSynced(
    String id,
    DateTime remoteUpdatedAt, {
    DirtyDeck? sentRevision,
  }) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_decks',
      {'updated_at': iso, 'base_updated_at': iso, 'is_synced': 1},
      where: sentRevision == null
          ? 'id = ?'
          : "id = ? AND is_synced = 0 AND name = ? AND COALESCE(course_id, '') = ? "
                "AND COALESCE(last_studied_at, '') = ? "
                "AND COALESCE(updated_at, '') = ? AND position = ?",
      whereArgs: [
        id,
        if (sentRevision != null) ...[
          sentRevision.name,
          sentRevision.courseId ?? '',
          sentRevision.lastStudiedAt?.toUtc().toIso8601String() ?? '',
          sentRevision.updatedAt?.toUtc().toIso8601String() ?? '',
          sentRevision.position,
        ],
      ],
    );
  }

  /// Removes only retained package leftovers whose exact pending references
  /// have now been acknowledged. The predicates are rechecked together in the
  /// transaction, so a concurrent local edit or new session keeps the row.
  Future<Set<String>> cleanupRetainedCards({Set<String>? deckIds}) async {
    final db = _db;
    if (db == null) return <String>{};
    return db.transaction((txn) async {
      final candidateRows = await txn.query(
        'offline_cards',
        columns: ['id', 'deck_id'],
        where: [
          'in_current_package = 0',
          'is_synced = 1',
          'content_dirty = 0',
          if (deckIds != null && deckIds.isNotEmpty)
            "deck_id IN (${List.filled(deckIds.length, '?').join(',')})",
        ].join(' AND '),
        whereArgs: deckIds == null || deckIds.isEmpty ? null : deckIds.toList(),
      );
      final changedDecks = <String>{};
      for (final row in candidateRows) {
        final id = row['id'] as String;
        final deckId = row['deck_id'] as String;
        final deleted = await txn.delete(
          'offline_cards',
          where: '''
            id = ?
            AND in_current_package = 0
            AND is_synced = 1
            AND content_dirty = 0
            AND NOT EXISTS (
              SELECT 1 FROM offline_deletions d
              WHERE d.entity_type = 'card' AND d.entity_id = offline_cards.id
            )
            AND NOT EXISTS (
              SELECT 1
              FROM offline_session_cards sc
              JOIN offline_study_sessions s ON s.id = sc.session_id
              WHERE sc.card_id = offline_cards.id AND (
                s.status = 'active' OR s.is_synced = 0 OR sc.is_synced = 0
              )
            )
          ''',
          whereArgs: [id],
        );
        if (deleted > 0) changedDecks.add(deckId);
      }
      return changedDecks;
    });
  }

  Future<List<LocalDeletion>> deckDeletions() => _deletions('deck');

  Future<List<LocalDeletion>> cardDeletions() => _deletions('card');

  Future<void> clearDeckDeletion(String id) => _clearDeletion('deck', id);

  Future<void> clearCardDeletion(String id) => _clearDeletion('card', id);

  Future<List<LocalDeletion>> _deletions(String entityType) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_deletions',
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );
    return [
      for (final r in rows)
        LocalDeletion(
          entityType: r['entity_type'] as String,
          entityId: r['entity_id'] as String,
          deckId: r['deck_id'] as String?,
          createdLocally: (r['created_locally'] as int) == 1,
        ),
    ];
  }

  Future<void> _clearDeletion(String entityType, String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete(
      'offline_deletions',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, id],
    );
  }

  Future<void> _writeTombstone(
    DatabaseExecutor txn,
    String entityType,
    String entityId, {
    String? deckId,
    required bool createdLocally,
  }) {
    return txn.insert('offline_deletions', {
      'entity_type': entityType,
      'entity_id': entityId,
      'deck_id': deckId,
      'created_locally': createdLocally ? 1 : 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- mapping ----------------------------------------------------------------

  Map<String, Object?> _cardValues(FlashCard c) {
    final updated = c.updatedAt.toUtc().toIso8601String();
    return {
      'id': c.id,
      'deck_id': c.deckId,
      'front': c.front,
      'back': c.back,
      // `keyword` (singular) is a dead column since R3 — left NULL.
      'keywords': jsonEncode(c.keywords),
      'is_concept': c.isConcept ? 1 : 0,
      'mastery_level': c.masteryLevel,
      'fail_count': c.failCount,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': updated,
      'base_updated_at': updated,
      'is_synced': 1,
      'content_dirty': 0,
    };
  }

  FlashCard _cardFromRow(Map<String, Object?> r) => FlashCard(
    id: r['id'] as String,
    deckId: r['deck_id'] as String,
    front: r['front'] as String,
    back: r['back'] as String,
    keywords: _decodeKeywords(r['keywords']),
    isConcept: (r['is_concept'] as int? ?? 0) == 1,
    masteryLevel: r['mastery_level'] as int,
    failCount: r['fail_count'] as int,
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String),
  );

  static List<String> _decodeKeywords(Object? raw) {
    if (raw is! String || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded.cast<String>() : const [];
  }

  DateTime? _parseNullable(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
