import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';

/// The frozen schema version 1 — the SQLite mirror as it was before
/// engine-v2-spec §5. A v1 database that runs `onUpgrade` must end up with the
/// exact schema a fresh v2 install creates; this snapshot plus
/// [AppDatabase.upgradeToV2Statements] is compared against
/// [AppDatabase.schemaStatements].
///
/// This list is history and must never change. If a later migration needs a
/// different starting point, add a v2→v3 delta and a matching v2 snapshot — do
/// not edit this one.
const List<String> _v1Schema = <String>[
  '''
  CREATE TABLE offline_decks (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    last_studied_at TEXT
  )
  ''',
  '''
  CREATE TABLE offline_cards (
    id              TEXT PRIMARY KEY,
    deck_id         TEXT NOT NULL,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    keyword         TEXT,
    mastery_level   INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    base_updated_at TEXT NOT NULL,
    is_synced       INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  '''
  CREATE TABLE offline_study_sessions (
    id             TEXT PRIMARY KEY,
    deck_id        TEXT NOT NULL,
    user_id        TEXT,
    status         TEXT NOT NULL,
    study_mode     TEXT NOT NULL,
    length_mode    TEXT NOT NULL,
    capped_length  INTEGER,
    mastery_delta  INTEGER,
    started_at     TEXT NOT NULL,
    completed_at   TEXT,
    is_synced      INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
  CREATE TABLE offline_session_cards (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL,
    card_id           TEXT NOT NULL,
    position          INTEGER NOT NULL,
    consecutive_fails INTEGER NOT NULL DEFAULT 0,
    is_parked         INTEGER NOT NULL DEFAULT 0,
    is_synced         INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
];

/// The frozen schema version 2 — the SQLite mirror as it was after
/// engine-v2-spec §5 and before the R3 card model. A v2 database that runs
/// `onUpgrade` must reach the same schema a fresh v3 install creates. Like
/// [_v1Schema], this list is history and must never change.
const List<String> _v2Schema = <String>[
  '''
  CREATE TABLE offline_decks (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    course_id       TEXT,
    last_studied_at TEXT
  )
  ''',
  '''
  CREATE TABLE offline_courses (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    accent_color TEXT NOT NULL,
    is_default   INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE offline_cards (
    id              TEXT PRIMARY KEY,
    deck_id         TEXT NOT NULL,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    keyword         TEXT,
    mastery_level   INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    base_updated_at TEXT NOT NULL,
    is_synced       INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  '''
  CREATE TABLE offline_study_sessions (
    id             TEXT PRIMARY KEY,
    deck_id        TEXT NOT NULL,
    user_id        TEXT,
    status         TEXT NOT NULL,
    study_mode     TEXT NOT NULL,
    length_mode    TEXT NOT NULL,
    capped_length  INTEGER,
    card_scope     TEXT NOT NULL DEFAULT 'due',
    mastery_delta  INTEGER,
    started_at     TEXT NOT NULL,
    completed_at   TEXT,
    is_synced      INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
  CREATE TABLE offline_session_cards (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL,
    card_id           TEXT NOT NULL,
    position          INTEGER NOT NULL,
    consecutive_fails INTEGER NOT NULL DEFAULT 0,
    is_parked         INTEGER NOT NULL DEFAULT 0,
    is_synced         INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
];

/// The frozen schema version 3 — the SQLite mirror as it was after the R3 card
/// model and before the offline-authoring sync surface (spec-v4). A v3 database
/// that runs `onUpgrade` must reach the same schema a fresh v4 install creates.
/// Like [_v1Schema] / [_v2Schema], this list is history and must never change.
const List<String> _v3Schema = <String>[
  '''
  CREATE TABLE offline_decks (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    course_id       TEXT,
    last_studied_at TEXT
  )
  ''',
  '''
  CREATE TABLE offline_courses (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    accent_color TEXT NOT NULL,
    is_default   INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE offline_cards (
    id              TEXT PRIMARY KEY,
    deck_id         TEXT NOT NULL,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    keyword         TEXT,
    keywords        TEXT NOT NULL DEFAULT '[]',
    is_concept      INTEGER NOT NULL DEFAULT 0,
    mastery_level   INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    base_updated_at TEXT NOT NULL,
    is_synced       INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  '''
  CREATE TABLE offline_study_sessions (
    id             TEXT PRIMARY KEY,
    deck_id        TEXT NOT NULL,
    user_id        TEXT,
    status         TEXT NOT NULL,
    study_mode     TEXT NOT NULL,
    length_mode    TEXT NOT NULL,
    capped_length  INTEGER,
    card_scope     TEXT NOT NULL DEFAULT 'due',
    mastery_delta  INTEGER,
    started_at     TEXT NOT NULL,
    completed_at   TEXT,
    is_synced      INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
  CREATE TABLE offline_session_cards (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL,
    card_id           TEXT NOT NULL,
    position          INTEGER NOT NULL,
    consecutive_fails INTEGER NOT NULL DEFAULT 0,
    is_parked         INTEGER NOT NULL DEFAULT 0,
    is_synced         INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
];

/// The frozen schema version 4 — the SQLite mirror as it was after the
/// offline-authoring sync surface (spec-v4) and before the milestone-D profile
/// metrics. A v4 database that runs `onUpgrade` must reach the same schema a
/// fresh v5 install creates. Like the earlier snapshots, this list is history
/// and must never change.
const List<String> _v4Schema = <String>[
  '''
  CREATE TABLE offline_decks (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    course_id         TEXT,
    last_studied_at   TEXT,
    created_at        TEXT,
    updated_at        TEXT,
    base_updated_at   TEXT,
    is_synced         INTEGER NOT NULL DEFAULT 1,
    is_pinned         INTEGER NOT NULL DEFAULT 0,
    mastery_level_sum INTEGER NOT NULL DEFAULT 0,
    total_cards       INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE offline_courses (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    accent_color    TEXT NOT NULL,
    is_default      INTEGER NOT NULL DEFAULT 0,
    user_id         TEXT,
    created_at      TEXT,
    updated_at      TEXT,
    base_updated_at TEXT,
    is_synced       INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE offline_cards (
    id              TEXT PRIMARY KEY,
    deck_id         TEXT NOT NULL,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    keyword         TEXT,
    keywords        TEXT NOT NULL DEFAULT '[]',
    is_concept      INTEGER NOT NULL DEFAULT 0,
    mastery_level   INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    base_updated_at TEXT NOT NULL,
    is_synced       INTEGER NOT NULL DEFAULT 1,
    content_dirty   INTEGER NOT NULL DEFAULT 0
  )
  ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  '''
  CREATE TABLE offline_study_sessions (
    id             TEXT PRIMARY KEY,
    deck_id        TEXT NOT NULL,
    user_id        TEXT,
    status         TEXT NOT NULL,
    study_mode     TEXT NOT NULL,
    length_mode    TEXT NOT NULL,
    capped_length  INTEGER,
    card_scope     TEXT NOT NULL DEFAULT 'due',
    mastery_delta  INTEGER,
    started_at     TEXT NOT NULL,
    completed_at   TEXT,
    is_synced      INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
  CREATE TABLE offline_session_cards (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL,
    card_id           TEXT NOT NULL,
    position          INTEGER NOT NULL,
    consecutive_fails INTEGER NOT NULL DEFAULT 0,
    is_parked         INTEGER NOT NULL DEFAULT 0,
    is_synced         INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
  '''
  CREATE TABLE offline_deletions (
    entity_type     TEXT NOT NULL,
    entity_id       TEXT NOT NULL,
    deck_id         TEXT,
    created_locally INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL
  )
  ''',
  'CREATE UNIQUE INDEX idx_offline_deletions_entity '
      'ON offline_deletions(entity_type, entity_id)',
];

/// The frozen schema version 5 — the SQLite mirror as it was after the
/// milestone-D profile metrics (`offline_study_sessions.cards_reviewed`) and
/// before the milestone-E3 offline-reorder / account-switch work. A v5 database
/// that runs `onUpgrade` must reach the same schema a fresh v6 install creates.
/// Like the earlier snapshots, this list is history and must never change.
const List<String> _v5Schema = <String>[
  '''
  CREATE TABLE offline_decks (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    course_id         TEXT,
    last_studied_at   TEXT,
    created_at        TEXT,
    updated_at        TEXT,
    base_updated_at   TEXT,
    is_synced         INTEGER NOT NULL DEFAULT 1,
    is_pinned         INTEGER NOT NULL DEFAULT 0,
    mastery_level_sum INTEGER NOT NULL DEFAULT 0,
    total_cards       INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE offline_courses (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    accent_color    TEXT NOT NULL,
    is_default      INTEGER NOT NULL DEFAULT 0,
    user_id         TEXT,
    created_at      TEXT,
    updated_at      TEXT,
    base_updated_at TEXT,
    is_synced       INTEGER NOT NULL DEFAULT 1
  )
  ''',
  '''
  CREATE TABLE offline_cards (
    id              TEXT PRIMARY KEY,
    deck_id         TEXT NOT NULL,
    front           TEXT NOT NULL,
    back            TEXT NOT NULL,
    keyword         TEXT,
    keywords        TEXT NOT NULL DEFAULT '[]',
    is_concept      INTEGER NOT NULL DEFAULT 0,
    mastery_level   INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    base_updated_at TEXT NOT NULL,
    is_synced       INTEGER NOT NULL DEFAULT 1,
    content_dirty   INTEGER NOT NULL DEFAULT 0
  )
  ''',
  'CREATE INDEX idx_offline_cards_deck ON offline_cards(deck_id)',
  '''
  CREATE TABLE offline_study_sessions (
    id             TEXT PRIMARY KEY,
    deck_id        TEXT NOT NULL,
    user_id        TEXT,
    status         TEXT NOT NULL,
    study_mode     TEXT NOT NULL,
    length_mode    TEXT NOT NULL,
    capped_length  INTEGER,
    card_scope     TEXT NOT NULL DEFAULT 'due',
    mastery_delta  INTEGER,
    cards_reviewed INTEGER,
    started_at     TEXT NOT NULL,
    completed_at   TEXT,
    is_synced      INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_sessions_deck ON offline_study_sessions(deck_id)',
  '''
  CREATE TABLE offline_session_cards (
    id                TEXT PRIMARY KEY,
    session_id        TEXT NOT NULL,
    card_id           TEXT NOT NULL,
    position          INTEGER NOT NULL,
    consecutive_fails INTEGER NOT NULL DEFAULT 0,
    is_parked         INTEGER NOT NULL DEFAULT 0,
    is_synced         INTEGER NOT NULL DEFAULT 1
  )
  ''',
  'CREATE INDEX idx_offline_session_cards_session '
      'ON offline_session_cards(session_id)',
  '''
  CREATE TABLE offline_deletions (
    entity_type     TEXT NOT NULL,
    entity_id       TEXT NOT NULL,
    deck_id         TEXT,
    created_locally INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL
  )
  ''',
  'CREATE UNIQUE INDEX idx_offline_deletions_entity '
      'ON offline_deletions(entity_type, entity_id)',
];

/// A normalized view of a schema: table -> (column -> definition), plus indexes.
class _Schema {
  final Map<String, Map<String, String>> tables = {};
  final Map<String, String> indexes = {};
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

List<String> _splitTopLevel(String body) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
    } else if (c == ',' && depth == 0) {
      parts.add(body.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(body.substring(start));
  return parts;
}

_Schema _build(List<String> statements) {
  final schema = _Schema();
  for (final raw in statements) {
    final s = _norm(raw);
    if (s.startsWith('create table ')) {
      final open = s.indexOf('(');
      final close = s.lastIndexOf(')');
      final name = s.substring('create table '.length, open).trim();
      final columns = <String, String>{};
      for (final part in _splitTopLevel(s.substring(open + 1, close))) {
        final p = part.trim();
        if (p.isEmpty) continue;
        final sp = p.indexOf(' ');
        final colName = sp == -1 ? p : p.substring(0, sp);
        columns[colName] = sp == -1 ? '' : p.substring(sp + 1).trim();
      }
      schema.tables[name] = columns;
    } else if (s.startsWith('alter table ')) {
      final m = RegExp(r'^alter table (\w+) add column (\w+) ?(.*)$')
          .firstMatch(s)!;
      schema.tables.putIfAbsent(m.group(1)!, () => {})[m.group(2)!] = m
          .group(3)!
          .trim();
    } else if (s.startsWith('create index ') ||
        s.startsWith('create unique index ')) {
      final m = RegExp(r'^create (unique )?index (\w+) on (.+)$')
          .firstMatch(s)!;
      schema.indexes[m.group(2)!] = '${m.group(1) ?? ''}${m.group(3)}';
    } else {
      fail('unrecognised schema statement: $s');
    }
  }
  return schema;
}

void main() {
  group('SQLite mirror schema parity', () {
    final fresh = _build(AppDatabase.schemaStatements);
    final upgradedFromV1 = _build([
      ..._v1Schema,
      ...AppDatabase.upgradeToV2Statements,
      ...AppDatabase.upgradeToV3Statements,
      ...AppDatabase.upgradeToV4Statements,
      ...AppDatabase.upgradeToV5Statements,
      ...AppDatabase.upgradeToV6Statements,
      ...AppDatabase.upgradeToV7Statements,
      ...AppDatabase.upgradeToV8Statements,
    ]);
    final upgradedFromV2 = _build([
      ..._v2Schema,
      ...AppDatabase.upgradeToV3Statements,
      ...AppDatabase.upgradeToV4Statements,
      ...AppDatabase.upgradeToV5Statements,
      ...AppDatabase.upgradeToV6Statements,
      ...AppDatabase.upgradeToV7Statements,
      ...AppDatabase.upgradeToV8Statements,
    ]);
    final upgradedFromV3 = _build([
      ..._v3Schema,
      ...AppDatabase.upgradeToV4Statements,
      ...AppDatabase.upgradeToV5Statements,
      ...AppDatabase.upgradeToV6Statements,
      ...AppDatabase.upgradeToV7Statements,
      ...AppDatabase.upgradeToV8Statements,
    ]);
    final upgradedFromV4 = _build([
      ..._v4Schema,
      ...AppDatabase.upgradeToV5Statements,
      ...AppDatabase.upgradeToV6Statements,
      ...AppDatabase.upgradeToV7Statements,
      ...AppDatabase.upgradeToV8Statements,
    ]);
    final upgradedFromV5 = _build([
      ..._v5Schema,
      ...AppDatabase.upgradeToV6Statements,
      ...AppDatabase.upgradeToV7Statements,
      ...AppDatabase.upgradeToV8Statements,
    ]);

    test(
      'a v1 database upgraded to the current version matches a fresh install '
      '— tables',
      () {
        expect(upgradedFromV1.tables, equals(fresh.tables));
      },
    );

    test(
      'a v1 database upgraded to the current version matches a fresh install '
      '— indexes',
      () {
        expect(upgradedFromV1.indexes, equals(fresh.indexes));
      },
    );

    test(
      'a v2 database upgraded to the current version matches a fresh install',
      () {
        expect(upgradedFromV2.tables, equals(fresh.tables));
        expect(upgradedFromV2.indexes, equals(fresh.indexes));
      },
    );

    test(
      'a v3 database upgraded to the current version matches a fresh install',
      () {
        expect(upgradedFromV3.tables, equals(fresh.tables));
        expect(upgradedFromV3.indexes, equals(fresh.indexes));
      },
    );

    test(
      'a v4 database upgraded to the current version matches a fresh install',
      () {
        expect(upgradedFromV4.tables, equals(fresh.tables));
        expect(upgradedFromV4.indexes, equals(fresh.indexes));
      },
    );

    test('a v5 database upgraded to current matches a fresh install', () {
      expect(upgradedFromV5.tables, equals(fresh.tables));
      expect(upgradedFromV5.indexes, equals(fresh.indexes));
    });

    test(
      'the fresh schema carries the milestone-E3 reorder + meta additions',
      () {
        expect(
          fresh.tables['offline_decks']!['position'],
          'integer not null default 0',
        );
        expect(
          fresh.tables['offline_courses']!['position'],
          'integer not null default 0',
        );
        expect(
          fresh.tables['offline_cards']!['created_locally'],
          'integer not null default 0',
        );
        expect(fresh.tables.containsKey('offline_meta'), isTrue);
      },
    );

    test('the fresh schema carries Phase 2 package-state columns', () {
      expect(
        fresh.tables['offline_cards']!['in_current_package'],
        'integer not null default 0',
      );
      expect(
        fresh.tables['offline_decks']!['remote_missing'],
        'integer not null default 0',
      );
      expect(
        fresh.tables['offline_decks']!['cache_suppressed'],
        'integer not null default 0',
      );
    });

    test('the fresh schema carries the milestone-D cards_reviewed column', () {
      expect(
        fresh.tables['offline_study_sessions']!.containsKey('cards_reviewed'),
        isTrue,
      );
    });

    test('the fresh schema carries the offline-authoring sync columns', () {
      expect(
        fresh.tables['offline_decks']!['is_synced'],
        'integer not null default 1',
      );
      expect(
        fresh.tables['offline_decks']!['is_pinned'],
        'integer not null default 0',
      );
      expect(fresh.tables['offline_courses']!.containsKey('is_synced'), isTrue);
      expect(
        fresh.tables['offline_cards']!['content_dirty'],
        'integer not null default 0',
      );
      expect(fresh.tables.containsKey('offline_deletions'), isTrue);
    });

    test('the fresh schema carries the Engine V2 additions', () {
      expect(
        fresh.tables.keys,
        containsAll(<String>[
          'offline_decks',
          'offline_courses',
          'offline_cards',
          'offline_study_sessions',
          'offline_session_cards',
        ]),
      );
      expect(fresh.tables['offline_decks']!.containsKey('course_id'), isTrue);
      expect(
        fresh.tables['offline_study_sessions']!['card_scope'],
        "text not null default 'due'",
      );
    });

    test('the fresh schema carries the R3 card-model columns', () {
      expect(
        fresh.tables['offline_cards']!['keywords'],
        "text not null default '[]'",
      );
      expect(
        fresh.tables['offline_cards']!['is_concept'],
        'integer not null default 0',
      );
    });
  });
}
