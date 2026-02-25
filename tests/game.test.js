const fs = require('fs');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, '../index.html'), 'utf8');
document.body.innerHTML = html;

const { SUITS, RANKS, HAND_TYPES, buildDeck, rankToValue, evaluateHand, getCardImageSrc } = require('../game.js');

describe('Card Game Unit Tests', () => {
  describe('buildDeck', () => {
    test('should create a deck with 52 unique cards', () => {
      const deck = buildDeck();
      expect(deck).toHaveLength(52);
      const cardSet = new Set(deck.map(card => `${card.rank}${card.suit}`));
      expect(cardSet.size).toBe(52);
    });

    test('should shuffle the deck', () => {
      const deck1 = buildDeck();
      const deck2 = buildDeck();
      // Since shuffle is random, check that they are not identical (low probability)
      const identical = deck1.every((card, index) => 
        card.rank === deck2[index].rank && card.suit === deck2[index].suit
      );
      expect(identical).toBe(false);
    });
  });

  describe('rankToValue', () => {
    test('should convert ranks to numeric values', () => {
      expect(rankToValue(2)).toBe(2);
      expect(rankToValue(10)).toBe(10);
      expect(rankToValue('J')).toBe(11);
      expect(rankToValue('Q')).toBe(12);
      expect(rankToValue('K')).toBe(13);
      expect(rankToValue('A')).toBe(14);
    });
  });

  describe('evaluateHand', () => {
    test('should evaluate High Card', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 4, suit: '♥' },
        { rank: 6, suit: '♦' },
        { rank: 8, suit: '♣' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.HIGH_CARD);
    });

    test('should evaluate Pair', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 6, suit: '♦' },
        { rank: 8, suit: '♣' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.PAIR);
    });

    test('should evaluate Two Pair', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 6, suit: '♦' },
        { rank: 6, suit: '♣' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.TWO_PAIR);
    });

    test('should evaluate Three of a Kind', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 2, suit: '♦' },
        { rank: 8, suit: '♣' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.THREE_KIND);
    });

    test('should evaluate Straight', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 3, suit: '♥' },
        { rank: 4, suit: '♦' },
        { rank: 5, suit: '♣' },
        { rank: 6, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.STRAIGHT);
    });

    test('should evaluate Flush', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 4, suit: '♠' },
        { rank: 6, suit: '♠' },
        { rank: 8, suit: '♠' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.FLUSH);
    });

    test('should evaluate Full House', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 2, suit: '♦' },
        { rank: 8, suit: '♣' },
        { rank: 8, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.FULL_HOUSE);
    });

    test('should evaluate Four of a Kind', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 2, suit: '♦' },
        { rank: 2, suit: '♣' },
        { rank: 10, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.FOUR_KIND);
    });

    test('should evaluate Straight Flush', () => {
      const hand = [
        { rank: 2, suit: '♠' },
        { rank: 3, suit: '♠' },
        { rank: 4, suit: '♠' },
        { rank: 5, suit: '♠' },
        { rank: 6, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.STRAIGHT_FLUSH);
    });

    test('should evaluate Royal Flush', () => {
      const hand = [
        { rank: 10, suit: '♠' },
        { rank: 'J', suit: '♠' },
        { rank: 'Q', suit: '♠' },
        { rank: 'K', suit: '♠' },
        { rank: 'A', suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.ROYAL_FLUSH);
    });

    test('should handle wheel straight (A-2-3-4-5)', () => {
      const hand = [
        { rank: 'A', suit: '♠' },
        { rank: 2, suit: '♥' },
        { rank: 3, suit: '♦' },
        { rank: 4, suit: '♣' },
        { rank: 5, suit: '♠' }
      ];
      expect(evaluateHand(hand)).toBe(HAND_TYPES.STRAIGHT);
    });
  });

  describe('getCardImageSrc', () => {
    test('should return correct image path for numbered cards', () => {
      expect(getCardImageSrc({ rank: 10, suit: '♠' })).toBe('assets/cards/10_of_spades.svg');
      expect(getCardImageSrc({ rank: 2, suit: '♥' })).toBe('assets/cards/2_of_hearts.svg');
    });

    test('should return correct image path for face cards', () => {
      expect(getCardImageSrc({ rank: 'J', suit: '♦' })).toBe('assets/cards/jack_of_diamonds.svg');
      expect(getCardImageSrc({ rank: 'Q', suit: '♣' })).toBe('assets/cards/queen_of_clubs.svg');
      expect(getCardImageSrc({ rank: 'K', suit: '♠' })).toBe('assets/cards/king_of_spades.svg');
      expect(getCardImageSrc({ rank: 'A', suit: '♥' })).toBe('assets/cards/ace_of_hearts.svg');
    });
  });
});