import 'package:flutter/foundation.dart';

/// A `courses` row (engine-v2-spec §3.1): the top-level grouping a deck belongs
/// to. Every user has exactly one [isDefault] course; a deck created without an
/// explicit course is attached to it server-side.
///
/// [accentColor] is a named key (`slate`, `red`, `amber`, …), constrained by a
/// database check constraint and mapped to an actual colour in the Flutter
/// theme layer during the UI revamp — not an arbitrary hex string. The default
/// course's key is `slate`.
@immutable
class Course {
  const Course({
    required this.id,
    required this.userId,
    required this.name,
    required this.accentColor,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.position = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        accentColor: json['accent_color'] as String,
        isDefault: json['is_default'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        position: json['position'] as int? ?? 0,
      );

  final String id;
  final String userId;
  final String name;
  final String accentColor;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The user's manual ordering key within their course list (milestone B).
  /// Ascending; ties broken by [createdAt]. Defaults to 0 for rows from a
  /// source that predates the column (e.g. the local offline mirror).
  final int position;

  @override
  bool operator ==(Object other) =>
      other is Course &&
      other.id == id &&
      other.userId == userId &&
      other.name == name &&
      other.accentColor == accentColor &&
      other.isDefault == isDefault &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.position == position;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        name,
        accentColor,
        isDefault,
        createdAt,
        updatedAt,
        position,
      );
}
