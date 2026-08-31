/// Pure helpers for manual drag-to-reorder of a list of ids and the mapping of
/// that order onto the integer `position` column decks and courses carry
/// (milestone B).
library;

/// Returns a new list with the item at [oldIndex] moved to [newIndex], where
/// [newIndex] is the destination index *after* the dragged item is removed —
/// the convention of `ReorderableListView.onReorderItem` and
/// `ReorderableGridView.onReorder` alike. Used as-is with no shift.
List<T> moveItemToIndex<T>(List<T> items, int oldIndex, int newIndex) {
  final next = [...items];
  final item = next.removeAt(oldIndex);
  next.insert(newIndex, item);
  return next;
}

/// Maps [orderedIds] onto contiguous zero-based positions in list order, so the
/// first id gets `position` 0, the next 1, and so on. Stable: feeding the result
/// back in (in position order) yields the same mapping.
Map<String, int> positionsForOrder(List<String> orderedIds) => {
      for (final (i, id) in orderedIds.indexed) id: i,
    };
