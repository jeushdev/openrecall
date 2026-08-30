/// The non-empty lines of one card side, split on `\n` with each line trimmed,
/// a leading `- ` / `* ` / `• ` bullet marker removed, and blank lines dropped.
/// Used to render a bulleted `back` in the Feynman reference view — the view
/// adds its own `•`, so a back written with `- ` markers must not double up
/// (`docs/spec-v3-card-model.md`, "Import (R5)").
///
/// (List mode, which this file's `ListContent` / `listContentOf` once served,
/// was removed in R3 — see docs/spec-v3-card-model.md.)
library;

final _leadingBullet = RegExp(r'^[-*•]\s+');

List<String> contentLines(String side) => side
    .split('\n')
    .map((line) => line.trim().replaceFirst(_leadingBullet, ''))
    .where((line) => line.isNotEmpty)
    .toList();
