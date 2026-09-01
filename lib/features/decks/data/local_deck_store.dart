import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/local_deletion.dart';
import '../domain/card.dart';
import '../domain/deck.dart';

/// A card row that has an unsynced local mastery/fail edit waiting to go up to
/// Supabase, together with [baseUpdatedAt] — the Supabase `updated_at` last seen
/// for it, which the sync pass uses as its compare-and-set target.
class DirtyCard {
  DirtyCard({
    required this.id,
    required this.masteryLevel,
    required this.failCount,
    required this.baseUpdatedAt,
  });

  final String id;
  final int masteryLevel;
  final int failCount;
  final DateTime baseUpdatedAt;
}

/// A deck row with an unsynced local edit (created / renamed / re-coursed
/// offline) waiting to go up to Supabase (spec-v4).
class DirtyDeck {
  DirtyDeck({
    required this.id,
    required this.name,
    required this.courseId,
    required this.baseUpdatedAt,
  });

  final String id;
  final String name;
  final String? courseId;
  final DateTime? baseUpdatedAt;

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
  LocalDeckStore(this._db);

  final Database? _db;

  /// True when there is no local database, so nothing can be cached or synced.
  bool get isNoop => _db == null;

  // ---- membership --------------------------------------------------------

  /// The ids of every cached deck (opened online or pinned).
  Future<Set<String>> downloadedDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db.query('offline_decks', columns: ['id']);
    return {for (final r in rows) r['id'] as String};
  }

  /// The ids of decks the user pinned "available offline" (`is_pinned = 1`).
  Future<Set<String>> pinnedDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db
        .query('offline_decks', columns: ['id'], where: 'is_pinned = 1');
    return {for (final r in rows) r['id'] as String};
  }

  Future<bool> isDownloaded(String deckId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query('offline_decks',
        columns: ['id'], where: 'id = ?', whereArgs: [deckId], limit: 1);
    return rows.isNotEmpty;
  }

  /// The ids of decks whose **cards** are mirrored locally — the decks that can
  /// actually be studied offline.
  ///
  /// Distinct from [downloadedDeckIds], which since spec-v4 returns every deck
  /// the user has: `refreshDeckMeta` writes an `offline_decks` header row for
  /// each one so the Library is browsable offline, long before any card set is
  /// mirrored. Row existence means "listed"; a row here means "studiable".
  Future<Set<String>> mirroredCardDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows =
        await db.rawQuery('SELECT DISTINCT deck_id FROM offline_cards');
    return {for (final r in rows) r['deck_id'] as String};
  }

  /// Whether [deckId]'s cards are mirrored locally. See [mirroredCardDeckIds].
  Future<bool> hasMirroredCards(String deckId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query('offline_cards',
        columns: ['id'], where: 'deck_id = ?', whereArgs: [deckId], limit: 1);
    return rows.isNotEmpty;
  }

  // ---- download / remove --------------------------------------------------

  /// Pins a deck "available offline": writes/refreshes the deck header, sets
  /// `is_pinned = 1`, and replaces its card mirror with a freshly-fetched set.
  Future<void> downloadDeck({
    required String deckId,
    required String name,
    String? courseId,
    DateTime? lastStudiedAt,
    required List<FlashCard> cards,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final exists = (await txn.query('offline_decks',
              columns: ['id'], where: 'id = ?', whereArgs: [deckId], limit: 1))
          .isNotEmpty;
      final header = {
        'name': name,
        'course_id': courseId,
        'last_studied_at': lastStudiedAt?.toUtc().toIso8601String(),
        'is_pinned': 1,
      };
      if (exists) {
        await txn
            .update('offline_decks', header, where: 'id = ?', whereArgs: [deckId]);
      } else {
        await txn.insert('offline_decks', {'id': deckId, ...header});
      }
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [deckId]);
      for (final c in cards) {
        await txn.insert('offline_cards', _cardValues(c));
      }
    });
  }

  /// Unpins a deck. If it still holds unsynced local work its row and cards are
  /// kept (just `is_pinned = 0`); otherwise its whole local footprint is
  /// dropped.
  Future<void> removeDeck(String deckId) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final unsynced = await _deckHasUnsyncedWork(txn, deckId);
      if (unsynced) {
        await txn.update('offline_decks', {'is_pinned': 0},
            where: 'id = ?', whereArgs: [deckId]);
        return;
      }
      final sessionIds = [
        for (final r in await txn.query('offline_study_sessions',
            columns: ['id'], where: 'deck_id = ?', whereArgs: [deckId]))
          r['id'] as String,
      ];
      for (final id in sessionIds) {
        await txn.delete('offline_session_cards',
            where: 'session_id = ?', whereArgs: [id]);
      }
      await txn.delete('offline_study_sessions',
          where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('offline_decks', where: 'id = ?', whereArgs: [deckId]);
    });
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

  Future<bool> _deckHasUnsyncedWork(
      DatabaseExecutor txn, String deckId) async {
    final deck = await txn.query('offline_decks',
        columns: ['is_synced'], where: 'id = ?', whereArgs: [deckId], limit: 1);
    if (deck.isNotEmpty && (deck.first['is_synced'] as int) == 0) return true;
    final card = await txn.query('offline_cards',
        columns: ['id'],
        where: 'deck_id = ? AND is_synced = 0',
        whereArgs: [deckId],
        limit: 1);
    if (card.isNotEmpty) return true;
    final session = await txn.query('offline_study_sessions',
        columns: ['id'],
        where: 'deck_id = ? AND is_synced = 0',
        whereArgs: [deckId],
        limit: 1);
    return session.isNotEmpty;
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
        for (final r in await txn.query('offline_decks',
            columns: ['id'], where: 'is_synced = 0'))
          r['id'] as String,
      };
      final remoteIds = {for (final d in remote) d.id};
      if (remoteIds.isEmpty) {
        await txn.delete('offline_decks', where: 'is_synced = 1');
      } else {
        await txn.delete(
          'offline_decks',
          where: 'is_synced = 1 AND id NOT IN '
              "(${List.filled(remoteIds.length, '?').join(',')})",
          whereArgs: remoteIds.toList(),
        );
      }
      for (final d in remote) {
        if (dirtyIds.contains(d.id)) continue;
        final exists = (await txn.query('offline_decks',
                columns: ['id'], where: 'id = ?', whereArgs: [d.id], limit: 1))
            .isNotEmpty;
        final meta = {
          'name': d.name,
          'course_id': d.courseId,
          'last_studied_at': d.lastStudiedAt?.toUtc().toIso8601String(),
          'mastery_level_sum': d.masteryLevelSum,
          'total_cards': d.totalCards,
          'is_synced': 1,
        };
        if (exists) {
          await txn.update('offline_decks', meta,
              where: 'id = ?', whereArgs: [d.id]);
        } else {
          await txn.insert('offline_decks', {'id': d.id, ...meta});
        }
      }
    });
  }

  /// Refreshes a deck's card mirror from a successful online fetch, without
  /// clobbering rows that still hold an unsynced local edit. Ensures the
  /// `offline_decks` row exists, so opening any deck online auto-caches it
  /// (unpinned).
  Future<void> mirrorCards(String deckId, List<FlashCard> remote) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final exists = (await txn.query('offline_decks',
              columns: ['id'], where: 'id = ?', whereArgs: [deckId], limit: 1))
          .isNotEmpty;
      if (!exists) {
        await txn.insert('offline_decks', {
          'id': deckId,
          'name': '',
          'is_synced': 1,
        });
      }
      final dirtyIds = {
        for (final r in await txn.query('offline_cards',
            columns: ['id'],
            where: 'deck_id = ? AND is_synced = 0',
            whereArgs: [deckId]))
          r['id'] as String,
      };
      final remoteIds = {for (final c in remote) c.id};
      if (remoteIds.isEmpty) {
        await txn.delete('offline_cards',
            where: 'deck_id = ? AND is_synced = 1', whereArgs: [deckId]);
      } else {
        await txn.delete(
          'offline_cards',
          where: 'deck_id = ? AND is_synced = 1 AND id NOT IN '
              "(${List.filled(remoteIds.length, '?').join(',')})",
          whereArgs: [deckId, ...remoteIds],
        );
      }
      for (final c in remote) {
        if (dirtyIds.contains(c.id)) continue;
        await txn.insert('offline_cards', _cardValues(c),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ---- offline reads --------------------------------------------------------

  /// Deck-Library summaries built entirely from the local mirror, for when the
  /// online fetch failed. Every cached deck appears — its card counts come from
  /// the mirrored cards when present, otherwise from the `mastery_level_sum` /
  /// `total_cards` stamped by [refreshDeckMeta].
  Future<List<DeckSummary>> cachedDeckSummaries() async {
    final db = _db;
    if (db == null) return const [];
    final decks = await db.query('offline_decks', orderBy: 'name');
    final result = <DeckSummary>[];
    for (final d in decks) {
      final id = d['id'] as String;
      final levels = [
        for (final r in await db.query('offline_cards',
            columns: ['mastery_level'], where: 'deck_id = ?', whereArgs: [id]))
          r['mastery_level'] as int,
      ];
      if (levels.isNotEmpty) {
        result.add(DeckSummary(
          id: id,
          name: d['name'] as String,
          courseId: d['course_id'] as String?,
          lastStudiedAt: _parseNullable(d['last_studied_at']),
          totalCards: levels.length,
          dueCards: levels.where((l) => l < masteredLevel).length,
          masteryPercent: masteryPercentFromLevels(levels),
          masteryLevelSum: levels.fold(0, (a, b) => a + b),
          createdAt: _parseNullable(d['created_at']),
        ));
      } else {
        final total = (d['total_cards'] as int?) ?? 0;
        final sum = (d['mastery_level_sum'] as int?) ?? 0;
        result.add(DeckSummary(
          id: id,
          name: d['name'] as String,
          courseId: d['course_id'] as String?,
          lastStudiedAt: _parseNullable(d['last_studied_at']),
          totalCards: total,
          dueCards: total, // level-per-card unknown; treated as all due
          masteryPercent: masteryPercentFromLevelSum(sum, total),
          masteryLevelSum: sum,
          createdAt: _parseNullable(d['created_at']),
        ));
      }
    }
    return result;
  }

  Future<List<FlashCard>> cards(String deckId) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_cards',
        where: 'deck_id = ?', whereArgs: [deckId], orderBy: 'created_at');
    return rows.map(_cardFromRow).toList();
  }

  Future<FlashCard?> cardById(String id) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db
        .query('offline_cards', where: 'id = ?', whereArgs: [id], limit: 1);
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

  /// Removes a deck offline: writes a tombstone and drops the deck, its cards
  /// and its local sessions. Individual card tombstones are not written — the
  /// deck-level delete cascades server-side.
  Future<void> deleteDeck(String id) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final row = await txn.query('offline_decks',
          columns: ['base_updated_at'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1);
      final createdLocally =
          row.isEmpty || row.first['base_updated_at'] == null;
      await _writeTombstone(txn, 'deck', id,
          createdLocally: createdLocally);
      // A card deleted-then-its-deck-deleted offline: the deck tombstone covers
      // it, so drop any stale card tombstones for this deck.
      final cardIds = [
        for (final r in await txn.query('offline_cards',
            columns: ['id'], where: 'deck_id = ?', whereArgs: [id]))
          r['id'] as String,
      ];
      for (final cid in cardIds) {
        await txn.delete('offline_deletions',
            where: 'entity_type = ? AND entity_id = ?', whereArgs: ['card', cid]);
      }
      final sessionIds = [
        for (final r in await txn.query('offline_study_sessions',
            columns: ['id'], where: 'deck_id = ?', whereArgs: [id]))
          r['id'] as String,
      ];
      for (final sid in sessionIds) {
        await txn.delete('offline_session_cards',
            where: 'session_id = ?', whereArgs: [sid]);
      }
      await txn.delete('offline_study_sessions',
          where: 'deck_id = ?', whereArgs: [id]);
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [id]);
      await txn.delete('offline_decks', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Inserts cards added / imported offline. The caller builds each [FlashCard]
  /// with a client-generated id; every row lands unsynced and content-dirty.
  Future<void> insertCards(List<FlashCard> cards) async {
    final db = _db;
    if (db == null) return;
    final batch = db.batch();
    for (final c in cards) {
      batch.insert('offline_cards', {
        ..._cardValues(c),
        'base_updated_at': null,
        'is_synced': 0,
        'content_dirty': 1,
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
      final row = await txn.query('offline_cards',
          columns: ['deck_id', 'base_updated_at'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1);
      if (row.isEmpty) return;
      final createdLocally = row.first['base_updated_at'] == null;
      await _writeTombstone(txn, 'card', id,
          deckId: row.first['deck_id'] as String?,
          createdLocally: createdLocally);
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
  Future<void> mirrorCardMastery(FlashCard row) async {
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
      where: 'id = ?',
      whereArgs: [row.id],
    );
  }

  /// Bumps a cached deck's last-studied stamp. Device-local, never synced back.
  Future<void> touchLastStudied(String deckId) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'offline_decks',
      {'last_studied_at': DateTime.now().toUtc().toIso8601String()},
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
    final rows = await db.query('offline_cards',
        where: 'is_synced = 0 AND content_dirty = 0');
    return [
      for (final r in rows)
        DirtyCard(
          id: r['id'] as String,
          masteryLevel: r['mastery_level'] as int,
          failCount: r['fail_count'] as int,
          baseUpdatedAt: DateTime.parse(r['base_updated_at'] as String),
        ),
    ];
  }

  Future<void> markCardSynced(String id, DateTime remoteUpdatedAt) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_cards',
      {'updated_at': iso, 'base_updated_at': iso, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
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
      String id, DateTime remoteUpdatedAt) async {
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
      },
      where: 'id = ?',
      whereArgs: [id],
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
          baseUpdatedAt: (r['base_updated_at'] as String?) == null
              ? null
              : DateTime.parse(r['base_updated_at'] as String),
        ),
    ];
  }

  Future<void> markDeckSynced(String id, DateTime remoteUpdatedAt) async {
    final db = _db;
    if (db == null) return;
    final iso = remoteUpdatedAt.toUtc().toIso8601String();
    await db.update(
      'offline_decks',
      {'updated_at': iso, 'base_updated_at': iso, 'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalDeletion>> deckDeletions() => _deletions('deck');

  Future<List<LocalDeletion>> cardDeletions() => _deletions('card');

  Future<void> clearDeckDeletion(String id) => _clearDeletion('deck', id);

  Future<void> clearCardDeletion(String id) => _clearDeletion('card', id);

  Future<List<LocalDeletion>> _deletions(String entityType) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_deletions',
        where: 'entity_type = ?', whereArgs: [entityType]);
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
    await db.delete('offline_deletions',
        where: 'entity_type = ? AND entity_id = ?', whereArgs: [entityType, id]);
  }

  Future<void> _writeTombstone(
    DatabaseExecutor txn,
    String entityType,
    String entityId, {
    String? deckId,
    required bool createdLocally,
  }) {
    return txn.insert(
      'offline_deletions',
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'deck_id': deckId,
        'created_locally': createdLocally ? 1 : 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
