import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';

void main() {
  test('fraction is done/total, clamped, and 1.0 for an empty deck', () {
    expect(const DownloadProgress(done: 0, total: 4).fraction, 0.0);
    expect(const DownloadProgress(done: 1, total: 4).fraction, 0.25);
    expect(const DownloadProgress(done: 4, total: 4).fraction, 1.0);
    // A deck with no cards is instantly "done", not a divide-by-zero.
    expect(const DownloadProgress(done: 0, total: 0).fraction, 1.0);
    // done can briefly exceed a stale total if a page over-fills; never > 1.
    expect(const DownloadProgress(done: 5, total: 4).fraction, 1.0);
  });

  test('isComplete when done has reached total', () {
    expect(const DownloadProgress(done: 3, total: 4).isComplete, isFalse);
    expect(const DownloadProgress(done: 4, total: 4).isComplete, isTrue);
    expect(const DownloadProgress(done: 0, total: 0).isComplete, isTrue);
  });
}
