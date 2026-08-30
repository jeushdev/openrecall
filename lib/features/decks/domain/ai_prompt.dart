/// The static text behind the Deck Creator's "Copy AI Prompt" button (spec §3).
///
/// This is a plain string copied to the clipboard for the user to paste into
/// any free web LLM. There is no AI API call anywhere in the app — this is the
/// only "AI" touchpoint, and it costs nothing.
///
/// The format it asks for is the block format the bulk parser reads
/// (`bulk_paste_parser.dart`, `docs/spec-v3-card-model.md` "Import (R5)").
library;

const String aiIngestionPrompt = '''
Turn the notes below into flashcards for a spaced-repetition study app.

FORMAT
Write each card as a block. Separate blocks with one blank line.
- The FIRST line of a block is the front: the question, prompt, or cue.
- The remaining lines are the back: the answer.
- A simple one-fact card may instead be a single line: FRONT | BACK

RULES
- For a list or multi-part answer, put one point per line on the back, each
  starting with "- ".
- To make a word or short phrase a fill-in-the-blank, wrap it in double braces
  wherever it appears, on any line. Use as many as apply, for example:
  The powerhouse of the cell is the {{mitochondria}}, which makes {{ATP}}.
- If a card is a broad idea, mechanism, or process worth explaining in your own
  words (not a bare fact or a vocabulary term), add a line reading exactly
  [concept] to its block. Write that card's back as the reference explanation,
  one point per line starting with "- ".
- Output only the card blocks. No numbering, no headings, no commentary.

EXAMPLE
What is the capital of Australia? | Canberra

Explain how a bill becomes law in the US.
[concept]
- A bill is introduced in the House or Senate and sent to committee.
- Both chambers must pass the same text.
- The {{president}} then signs it or vetoes it.

NOTES
<paste your notes here>
''';
