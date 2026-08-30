/// A tombstone for a course / deck / card deleted while offline (spec-v4).
///
/// [SyncService] replays these on reconnect in reverse foreign-key order
/// (card, then deck, then course). [createdLocally] marks a row that never
/// reached Supabase — created offline and deleted before it ever synced — so
/// its remote delete is skipped.
class LocalDeletion {
  const LocalDeletion({
    required this.entityType,
    required this.entityId,
    required this.deckId,
    required this.createdLocally,
  });

  final String entityType;
  final String entityId;

  /// Set only for a `card` tombstone, so the sync pass can resolve push order.
  final String? deckId;
  final bool createdLocally;
}
