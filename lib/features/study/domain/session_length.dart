/// Whether a session runs until every card is Mastered or parked (spec §5), or
/// stops after a fixed number of distinct cards (spec §4).
///
/// The value names are the UI's; [SessionLengthModeDb.db] maps them onto the
/// `study_sessions.length_mode` column (`uncapped` | `capped`).
enum SessionLengthMode { untilMastered, capped }

/// The fixed cap presets (spec §4: "10/20/30/All", not freeform entry). `null`
/// is the "All" preset — a capped session with no numeric cap, so every
/// filtered card enters the queue.
const List<int?> sessionCapPresets = [10, 20, 30, null];

extension SessionLengthModeDb on SessionLengthMode {
  /// The `study_sessions.length_mode` string this mode is stored as.
  String get db =>
      this == SessionLengthMode.capped ? 'capped' : 'uncapped';
}

/// Reads a `study_sessions.length_mode` string back into a [SessionLengthMode].
SessionLengthMode sessionLengthModeFromDb(String value) =>
    value == 'capped' ? SessionLengthMode.capped : SessionLengthMode.untilMastered;
