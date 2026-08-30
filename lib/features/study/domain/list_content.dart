/// The non-empty lines of one card side, split on `\n` with each line trimmed
/// and blank lines dropped. Used to render a bulleted `back` in the Feynman
/// reference view.
///
/// (List mode, which this file's `ListContent` / `listContentOf` once served,
/// was removed in R3 — see docs/spec-v3-card-model.md.)
library;

List<String> contentLines(String side) => side
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();
