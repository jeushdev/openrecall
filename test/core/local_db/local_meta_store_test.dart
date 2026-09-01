import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/local_meta_store.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';

import '../../support/local_db_harness.dart';

/// `offline_meta` + the account-switch mirror wipe (milestone E3 Task 7).
void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalMetaStore meta;
  late LocalDeckStore decks;
  late LocalCourseStore courses;

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    meta = LocalMetaStore(db.db);
    decks = LocalDeckStore(db.db);
    courses = LocalCourseStore(db.db);
  });

  test('lastUserId round-trips', () async {
    expect(await meta.lastUserId(), isNull);
    await meta.setLastUserId('user-a');
    expect(await meta.lastUserId(), 'user-a');
    await meta.setLastUserId('user-b');
    expect(await meta.lastUserId(), 'user-b');
  });

  test('wipeMirror clears every offline_* table but leaves offline_meta',
      () async {
    await meta.setLastUserId('user-a');
    await decks.pinDeck(deckId: 'd1', name: 'A');
    await decks.insertCards([
      FlashCard(
        id: 'k1', deckId: 'd1', front: 'Q', back: 'A',
        keywords: const [], isConcept: false, masteryLevel: 0, failCount: 0,
        createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      ),
    ]);
    await courses.refreshCourses([
      Course(
        id: 'c1', userId: 'user-a', name: 'Bio', accentColor: 'green',
        isDefault: false, createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);

    await meta.wipeMirror();

    expect(await decks.cachedDeckSummaries(), isEmpty);
    expect(await decks.cards('d1'), isEmpty);
    expect(await courses.cachedCourses(), isEmpty);
    expect(await meta.lastUserId(), 'user-a', reason: 'meta survives the wipe');
  });
}
