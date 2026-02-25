const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');
document.body.innerHTML = html;

const game = require('../game.js');
const { state, newRun, playSelected, discardSelected, toggleSelection } = game;

game.disableAnimation = true;

describe('Card Game Integration Tests', () => {
  beforeEach(() => {
    // Reset state before each test
    newRun();
  });

  test('newRun should initialize game state', () => {
    expect(state.ante).toBe(1);
    expect(state.score).toBe(0);
    expect(state.hands).toBe(4);
    expect(state.discards).toBe(3);
    expect(state.hand).toHaveLength(8);
    expect(state.deck).toHaveLength(44); // 52 - 8
    expect(state.selected.size).toBe(0);
    expect(state.gameOver).toBe(false);
  });

  test('toggleSelection should add and remove cards from selection', () => {
    expect(state.selected.has(0)).toBe(false);
    toggleSelection(0);
    expect(state.selected.has(0)).toBe(true);
    toggleSelection(0);
    expect(state.selected.has(0)).toBe(false);
  });

  test('playSelected should allow playing fewer than 5 cards', async () => {
    // Select 2 cards
    toggleSelection(0);
    toggleSelection(1);
    await playSelected();
    expect(state.hands).toBe(3); // Decreased
  });

  test('discardSelected should discard cards and replenish', async () => {
    const initialHandLength = state.hand.length;
    toggleSelection(0);
    await discardSelected();
    expect(state.discards).toBe(2);
    expect(state.hand).toHaveLength(initialHandLength); // Replenished
  });

  test('should handle game over on no hands left', async () => {
    // Force hands to 1
    state.hands = 1;
    // Select 5 cards
    for (let i = 0; i < 5; i++) {
      toggleSelection(i);
    }
    await playSelected();
    expect(state.gameOver).toBe(true);
  });
});
