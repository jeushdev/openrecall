import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/requeue.dart';

void main() {
  group('requeuePosition', () {
    test('with 4+ cards ahead, slots strictly between the 3rd and 4th', () {
      final pos = requeuePosition([
        1000,
        2000,
        3000,
        4000,
        5000,
      ], currentPosition: 500);
      expect(pos, greaterThan(3000));
      expect(pos, lessThan(4000));
    });

    test('with exactly 3 cards ahead, goes to the back of the queue', () {
      expect(requeuePosition([1000, 2000, 3000], currentPosition: 500), 4000);
    });

    test('with fewer than 3 cards ahead, goes to the back of the queue', () {
      expect(requeuePosition([1000, 2000], currentPosition: 500), 3000);
      expect(requeuePosition([1000], currentPosition: 500), 2000);
    });

    test(
      'with no cards ahead, repeats immediately after the current position',
      () {
        expect(requeuePosition(const [], currentPosition: 4000), 5000);
      },
    );

    test(
      'repeated requeues into one gap stay strictly increasing and unique',
      () {
        // Queue of 6 cards at 1000..6000; fail the front card over and over.
        var positions = [1000, 2000, 3000, 4000, 5000, 6000];
        final seen = <int>{};
        for (var i = 0; i < 50; i++) {
          final current = positions.first;
          final ahead = positions.sublist(1);
          final next = requeuePosition(ahead, currentPosition: current);
          expect(seen.add(next), isTrue, reason: 'duplicate position $next');
          expect(
            ahead.where((p) => p < next).length,
            greaterThanOrEqualTo(3),
            reason: 'should land at least 3 cards deep when possible',
          );
          positions = [...ahead, next]..sort();
        }
      },
    );
  });
}
