/// The static text behind the Deck Creator's "Copy AI Prompt" button (spec §3).
///
/// This is a plain string copied to the clipboard for the user to paste into
/// any free web LLM. There is no AI API call anywhere in the app — this is the
/// only "AI" touchpoint, and it costs nothing.
library;

const String aiIngestionPrompt = '''
Turn the notes below into flashcards for a spaced-repetition study app.

FORMAT
Output one flashcard per line, exactly:
FRONT | BACK

RULES
- Separate the front from the back with a single pipe character ( | ).
- FRONT is the question or cue. BACK is the answer. Keep each card to one line.
- If a single word or short phrase is the thing worth testing, wrap that one
  term in double braces on whichever side it appears, for example:
  The powerhouse of the cell is the {{mitochondria}}.
  Use at most one {{ }} marker per card.
- Output only the card lines. No numbering, no bullet points, no headings,
  no commentary.

NOTES
<paste your notes here>
''';
