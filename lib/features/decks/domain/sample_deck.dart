/// The pre-made starter deck offered from the empty Deck Library (spec §2:
/// "no decks yet → prompt to create first deck, with a link to a small pre-made
/// sample deck").
///
/// This is plain data. [DecksController.seedSampleDeck] turns it into a real
/// deck + cards in Supabase through the normal repository path, so a first-run
/// user has something to study every mode against without typing anything in.
///
/// The card mix is deliberate — it exercises all three study modes
/// (docs/spec-v3-card-model.md, read-time mode detection):
/// - every card supports **Flip** (multi-line backs render as bullets);
/// - the cards with `keywords` add **Cloze** (each keyword also appears in the
///   front/back, so the blank lands on real words);
/// - the `isConcept` cards add **Feynman** (front is the prompt, back the
///   reference).
library;

/// The name the seeded deck is created with.
const String sampleDeckName = 'Sample deck';

/// One seed card: front + back, plus its Cloze keywords and concept flag.
typedef SampleCard = ({
  String front,
  String back,
  List<String> keywords,
  bool isConcept,
});

/// The seed cards, in the order they should be inserted.
const List<SampleCard> sampleDeckCards = [
  // Plain flip-and-rate facts — no single word worth blanking.
  (
    front: 'What is the capital of Australia?',
    back: 'Canberra',
    keywords: [],
    isConcept: false,
  ),
  (
    front: 'In what year did the Apollo 11 crew first land on the Moon?',
    back: '1969',
    keywords: [],
    isConcept: false,
  ),
  (
    front: 'Who wrote the play "Romeo and Juliet"?',
    back: 'William Shakespeare',
    keywords: [],
    isConcept: false,
  ),
  // Keyworded cards — these light up Cloze. Each keyword appears verbatim in
  // the card text so the blank replaces a real word.
  (
    front: 'The organelle that generates most of a cell’s energy is the '
        'mitochondria, which produces ATP.',
    back: 'It makes ATP through cellular respiration.',
    keywords: ['mitochondria', 'ATP'],
    isConcept: false,
  ),
  (
    front: 'What is the chemical symbol for gold?',
    back: 'Au',
    keywords: ['Au'],
    isConcept: false,
  ),
  (
    front: 'The Great Barrier Reef lies off the northeastern coast of Australia.',
    back: 'It is the world’s largest coral reef system.',
    keywords: ['Australia'],
    isConcept: false,
  ),
  // Multi-line back — flip-and-rate recall lists, rendered as bullets.
  (
    front: 'Name the three branches of the U.S. federal government.',
    back: 'Legislative\nExecutive\nJudicial',
    keywords: [],
    isConcept: false,
  ),
  (
    front: 'What are the four classical states of matter?',
    back: 'Solid\nLiquid\nGas\nPlasma',
    keywords: [],
    isConcept: false,
  ),
  // Concept cards — these light up Feynman. The front is the prompt to explain
  // in your own words; the multi-line back is the reference.
  (
    front: 'Explain supply and demand in your own words.',
    back: 'As a good’s price rises, suppliers want to sell more but buyers '
        'want to buy less.\n'
        'As the price falls, buyers want more but suppliers offer less.\n'
        'The market price settles where quantity supplied meets quantity '
        'demanded.',
    keywords: [],
    isConcept: true,
  ),
  (
    front: 'Explain why Earth has seasons.',
    back: 'Earth’s axis is tilted about 23.5 degrees relative to its '
        'orbit.\n'
        'As Earth orbits the Sun, each hemisphere spends part of the year '
        'tilted toward the Sun and part tilted away.\n'
        'The hemisphere tilted toward the Sun gets more direct light and '
        'longer days — that is its summer.',
    keywords: [],
    isConcept: true,
  ),
];
