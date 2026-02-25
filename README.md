# Open Balatro Prototype

A minimal open-source starter inspired by Balatro.

## What this prototype includes

- 52-card deck with draw/discard loop.
- Select up to 5 cards and score poker hands.
- Blind-style target score that scales by ante.
- Limited hands and discards per ante.
- Minimal dependencies for testing; pure HTML/CSS/JS for the game.

## Run locally

```bash
python3 -m http.server 8080
```

Then open <http://localhost:8080>.

## Testing

Install dependencies and run tests:

```bash
npm install
npm test
```

For test coverage:

```bash
npm run test:coverage
```

Tests include unit tests for game logic and integration tests for game flow.

## Next ideas

- Joker cards and deck modifiers.
- Shop, economy, and rerolls.
- Seeded runs and persistent unlocks.
- Better balancing and effects.
