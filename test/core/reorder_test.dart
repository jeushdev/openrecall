import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/reorder.dart';

void main() {
  group('moveItemToIndex', () {
    test('inserts at the post-removal newIndex as-is', () {
      // newIndex is the destination *after* the dragged item is removed, so
      // moving 'a' (0) to the end is newIndex 2, and it lands last.
      expect(moveItemToIndex(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
      expect(moveItemToIndex(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('a no-op move returns an equal list', () {
      expect(moveItemToIndex(['a', 'b', 'c'], 1, 1), ['a', 'b', 'c']);
    });

    test('does not mutate the input list', () {
      final input = ['a', 'b', 'c'];
      moveItemToIndex(input, 0, 2);
      expect(input, ['a', 'b', 'c']);
    });
  });

  group('positionsForOrder', () {
    test('maps ids to contiguous zero-based positions in list order', () {
      expect(positionsForOrder(['x', 'y', 'z']), {'x': 0, 'y': 1, 'z': 2});
    });

    test('an empty order maps to an empty result', () {
      expect(positionsForOrder(const []), isEmpty);
    });

    test('is stable — applying it twice yields the same positions', () {
      final once = positionsForOrder(['x', 'y', 'z']);
      final ordered = once.keys.toList()
        ..sort((a, b) => once[a]!.compareTo(once[b]!));
      expect(positionsForOrder(ordered), once);
    });
  });
}
