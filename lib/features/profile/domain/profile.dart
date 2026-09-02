/// The current user's `profiles` row, as the identity UI needs it.
///
/// [username] is the optional, user-set display name (spec:
/// docs/superpowers/specs/2026-09-03-editable-username-design.md). When it is
/// null or blank the UI falls back to the email-derived name — see
/// `displayNameOr` in `lib/ui/common/avatar.dart`.
typedef Profile = ({String id, String email, String? username});
