import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';

/// The reorder push payloads (milestone E3). The RPC round-trip itself is the
/// manual airplane-mode walkthrough's job (Task 8) — this pins the shape of the
/// `items` list `SyncService` hands to `set_deck_positions` /
/// `set_course_positions`.
void main() {
  DirtyDeck deck(String id, int position) => DirtyDeck(
        id: id,
        name: id,
        courseId: 'c1',
        baseUpdatedAt: DateTime.utc(2026),
        position: position,
      );

  DirtyCourse course(String id, int position) => DirtyCourse(
        id: id,
        userId: 'u1',
        name: id,
        accentColor: 'green',
        isDefault: false,
        updatedAt: DateTime.utc(2026),
        baseUpdatedAt: DateTime.utc(2026),
        position: position,
      );

  test('deckPositionItems maps each dirty deck to its {id, position}', () {
    expect(
      deckPositionItems([deck('a', 1), deck('b', 0)]),
      [
        {'id': 'a', 'position': 1},
        {'id': 'b', 'position': 0},
      ],
    );
  });

  test('coursePositionItems does the same for courses', () {
    expect(
      coursePositionItems([course('a', 2), course('b', 0), course('c', 1)]),
      [
        {'id': 'a', 'position': 2},
        {'id': 'b', 'position': 0},
        {'id': 'c', 'position': 1},
      ],
    );
  });

  test('an empty dirty list yields an empty payload', () {
    expect(deckPositionItems(const []), isEmpty);
    expect(coursePositionItems(const []), isEmpty);
  });
}
