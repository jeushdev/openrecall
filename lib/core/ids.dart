import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A fresh v4 UUID for a row created while offline. Supabase generates these
/// server-side with `gen_random_uuid()`; a fully-offline `study_sessions` /
/// `session_cards` row is given its permanent id here from the start, so there
/// is no "swap the temporary id" step once it syncs (spec §10).
String newUuid() => _uuid.v4();
