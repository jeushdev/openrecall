/// The pre-made starter deck offered from the empty Deck Library (spec §2:
/// "no decks yet → prompt to create first deck, with a link to a small pre-made
/// sample deck").
///
/// This is plain data. [DecksController.seedSampleDeck] turns it into a real
/// deck + cards in Supabase through the normal repository path, so a first-run
/// user has something to study every mode against without typing anything in.
///
/// The card mix is deliberate — it exercises all four study modes (spec §4's
/// read-time mode detection):
/// - every card supports **Flip**;
/// - the cards with a `keyword` add **Cloze** (the keyword text also appears in
///   the front/back, so the blank lands on real words);
/// - the cards with a multi-line `back` add **List** and **Feynman**.
library;

/// The name the seeded deck is created with.
const String sampleDeckName = 'Sample deck';

/// One seed card: the same three fields the Deck Creator collects (spec §3).
typedef SampleCard = ({String front, String back, String? keyword});

/// The seed cards, in the order they should be inserted.
const List<SampleCard> sampleDeckCards = [
  // Plain flip-and-rate facts — no single word worth blanking.
  (
    front: 'What is the capital of Australia?',
    back: 'Canberra',
    keyword: null,
  ),
  (
    front: 'In what year did the Apollo 11 crew first land on the Moon?',
    back: '1969',
    keyword: null,
  ),
  (
    front: 'Who wrote the play "Romeo and Juliet"?',
    back: 'William Shakespeare',
    keyword: null,
  ),
  // Keyworded cards — these light up Cloze. The keyword appears verbatim in the
  // card text so the blank replaces a real word.
  (
    front: 'The organelle that generates most of a cell’s energy is the '
        'mitochondria.',
    back: 'It produces ATP through cellular respiration.',
    keyword: 'mitochondria',
  ),
  (
    front: 'What is the chemical symbol for gold?',
    back: 'Au',
    keyword: 'Au',
  ),
  (
    front: 'The Great Barrier Reef lies off the northeastern coast of Australia.',
    back: 'It is the world’s largest coral reef system.',
    keyword: 'Australia',
  ),
  // Multi-line back — these light up List and Feynman.
  (
    front: 'Name the three branches of the U.S. federal government.',
    back: 'Legislative\nExecutive\nJudicial',
    keyword: null,
  ),
  (
    front: 'What are the four classical states of matter?',
    back: 'Solid\nLiquid\nGas\nPlasma',
    keyword: null,
  ),
  (
    front: 'Explain supply and demand in your own words.',
    back: 'As a good’s price rises, suppliers want to sell more but buyers '
        'want to buy less.\n'
        'As the price falls, buyers want more but suppliers offer less.\n'
        'The market price settles where quantity supplied meets quantity '
        'demanded.',
    keyword: null,
  ),
  (
    front: 'Explain why Earth has seasons.',
    back: 'Earth’s axis is tilted about 23.5 degrees relative to its '
        'orbit.\n'
        'As Earth orbits the Sun, each hemisphere spends part of the year '
        'tilted toward the Sun and part tilted away.\n'
        'The hemisphere tilted toward the Sun gets more direct light and '
        'longer days — that is its summer.',
    keyword: null,
  ),
];
