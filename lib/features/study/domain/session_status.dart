/// The lifecycle of a `study_sessions` row (spec schema): `active` while it can
/// be resumed, `completed` once every queued card is Mastered or parked, and
/// `abandoned` when a newer session on the same deck supersedes it.
///
/// The value names equal the stored strings.
enum SessionStatus { active, completed, abandoned }

/// Reads a `study_sessions.status` string back into a [SessionStatus].
SessionStatus sessionStatusFromDb(String value) =>
    SessionStatus.values.byName(value);
