import 'package:sqflite/sqflite.dart';

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

/// DAO for the `offline_decks` / `offline_cards` tables (spec §10).
///
/// A deck is "downloaded" exactly when it has a row in `offline_decks`. When
/// [_db] is `null` (no local database — the default outside `main()`), every
/// read returns empty and every write is a no-op, so a cache-first repository
/// wrapping this store behaves like the plain Supabase one.
class LocalDeckStore {
  LocalDeckStore(this._db);

  final Database? _db;

  /// True when there is no local database, so nothing can be cached or synced.
  bool get isNoop => _db == null;

  // ---- downloaded-deck membership -----------------------------------------

  Future<Set<String>> downloadedDeckIds() async {
    final db = _db;
    if (db == null) return <String>{};
    final rows = await db.query('offline_decks', columns: ['id']);
    return {for (final r in rows) r['id'] as String};
  }

  Future<bool> isDownloaded(String deckId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query('offline_decks',
        columns: ['id'], where: 'id = ?', whereArgs: [deckId], limit: 1);
    return rows.isNotEmpty;
  }

  // ---- download / remove --------------------------------------------------

  /// Writes the initial mirror for a deck the user just toggled "available
  /// offline": the deck header plus a full, freshly-fetched card set.
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
      await txn.insert(
        'offline_decks',
        {
          'id': deckId,
          'name': name,
          'course_id': courseId,
          'last_studied_at': lastStudiedAt?.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [deckId]);
      for (final c in cards) {
        await txn.insert('offline_cards', _cardValues(c));
      }
    });
  }

  /// Drops a deck's entire local footprint when the toggle is turned off.
  Future<void> removeDeck(String deckId) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final sessionIds = [
        for (final r in await txn.query('offline_study_sessions',
            columns: ['id'], where: 'deck_id = ?', whereArgs: [deckId]))
          r['id'] as String,
      ];
      for (final id in sessionIds) {
        await txn.delete('offline_session_cards',
            where: 'session_id = ?', whereArgs: [id]);
      }
      await txn
          .delete('offline_study_sessions', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('offline_cards', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('offline_decks', where: 'id = ?', whereArgs: [deckId]);
    });
  }

  // ---- read-through refresh ---------------------------------------------------

  /// Updates the cached header (name, last-studied) for whichever of [remote]
  /// decks are downloaded. Called after every successful online deck-list fetch.
  Future<void> refreshDeckMeta(List<DeckSummary> remote) async {
    final db = _db;
    if (db == null) return;
    final downloaded = await downloadedDeckIds();
    if (downloaded.isEmpty) return;
    final batch = db.batch();
    for (final d in remote) {
      if (!downloaded.contains(d.id)) continue;
      batch.update(
        'offline_decks',
        {
          'name': d.name,
          'course_id': d.courseId,
          'last_studied_at': d.lastStudiedAt?.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [d.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Refreshes a downloaded deck's card mirror from a successful online fetch,
  /// without clobbering rows that still hold an unsynced local edit.
  Future<void> mirrorCards(String deckId, List<FlashCard> remote) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      final dirtyIds = {
        for (final r in await txn.query('offline_cards',
            columns: ['id'],
            where: 'deck_id = ? AND is_synced = 0',
            whereArgs: [deckId]))
          r['id'] as String,
      };
      final remoteIds = {for (final c in remote) c.id};
      // Drop synced local rows that no longer exist remotely.
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
  /// online fetch failed. Only downloaded decks appear.
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
      result.add(DeckSummary(
        id: id,
        name: d['name'] as String,
        courseId: d['course_id'] as String?,
        lastStudiedAt: _parseNullable(d['last_studied_at']),
        totalCards: levels.length,
        dueCards: levels.where((l) => l < masteredLevel).length,
        masteryPercent: masteryPercentFromLevels(levels),
        masteryLevelSum: levels.fold(0, (a, b) => a + b),
      ));
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

  // ---- offline writes ------------------------------------------------------

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
      keyword: existing.keyword,
      masteryLevel: masteryLevel,
      failCount: failCount,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  /// Mirrors a confirmed Supabase mastery write into the local row and re-bases
  /// its compare-and-set target. Keeps the mirror fresh for the next time the
  /// deck is studied offline.
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

  /// Bumps a downloaded deck's cached last-studied stamp. No-op if not
  /// downloaded. This stamp is device-local and never synced back (decks are
  /// not part of the sync surface, spec §10).
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

  Future<List<DirtyCard>> unsyncedCards() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('offline_cards', where: 'is_synced = 0');
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

  // ---- mapping ----------------------------------------------------------------

  Map<String, Object?> _cardValues(FlashCard c) {
    final updated = c.updatedAt.toUtc().toIso8601String();
    return {
      'id': c.id,
      'deck_id': c.deckId,
      'front': c.front,
      'back': c.back,
      'keyword': c.keyword,
      'mastery_level': c.masteryLevel,
      'fail_count': c.failCount,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': updated,
      'base_updated_at': updated,
      'is_synced': 1,
    };
  }

  FlashCard _cardFromRow(Map<String, Object?> r) => FlashCard(
        id: r['id'] as String,
        deckId: r['deck_id'] as String,
        front: r['front'] as String,
        back: r['back'] as String,
        keyword: r['keyword'] as String?,
        masteryLevel: r['mastery_level'] as int,
        failCount: r['fail_count'] as int,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
      );

  DateTime? _parseNullable(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
