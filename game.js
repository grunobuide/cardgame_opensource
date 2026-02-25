const SUITS = ["♠", "♥", "♦", "♣"];
const RANKS = [2, 3, 4, 5, 6, 7, 8, 9, 10, "J", "Q", "K", "A"];
const ANTE_TARGETS = [200, 400, 700];

const HAND_TYPES = {
  HIGH_CARD: { label: "High Card", chips: 5, mult: 1 },
  PAIR: { label: "Pair", chips: 10, mult: 2 },
  TWO_PAIR: { label: "Two Pair", chips: 20, mult: 2 },
  THREE_KIND: { label: "Three of a Kind", chips: 30, mult: 3 },
  STRAIGHT: { label: "Straight", chips: 30, mult: 4 },
  FLUSH: { label: "Flush", chips: 35, mult: 4 },
  FULL_HOUSE: { label: "Full House", chips: 40, mult: 4 },
  FOUR_KIND: { label: "Four of a Kind", chips: 60, mult: 7 },
  STRAIGHT_FLUSH: { label: "Straight Flush", chips: 100, mult: 8 },
  ROYAL_FLUSH: { label: "Royal Flush", chips: 150, mult: 10 },
};

const state = {
  ante: 1,
  score: 0,
  hands: 4,
  discards: 2,
  deck: [],
  hand: [],
  selected: new Set(),
  gameOver: false,
};

let ui = {};

if (typeof document !== 'undefined' && document.getElementById) {
  ui = {
    ante: document.getElementById("ante"),
    target: document.getElementById("target"),
    score: document.getElementById("score"),
    hands: document.getElementById("hands"),
    discards: document.getElementById("discards"),
    hand: document.getElementById("hand"),
    message: document.getElementById("message"),
    playBtn: document.getElementById("play-btn"),
    discardBtn: document.getElementById("discard-btn"),
    newRunBtn: document.getElementById("new-run-btn"),
  };
}

function buildDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({ suit, rank });
    }
  }

  for (let i = deck.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function targetScore() {
  return ANTE_TARGETS[state.ante - 1] || ANTE_TARGETS[ANTE_TARGETS.length - 1] + (state.ante - ANTE_TARGETS.length) * 300;
}

function drawCards(count) {
  for (let i = 0; i < count; i += 1) {
    if (state.deck.length === 0) {
      state.deck = buildDeck();
    }
    state.hand.push(state.deck.pop());
  }
}

function rankToValue(rank) {
  if (typeof rank === "number") return rank;
  if (rank === "J") return 11;
  if (rank === "Q") return 12;
  if (rank === "K") return 13;
  return 14;
}

function evaluateHand(cards) {
  const values = cards.map((card) => rankToValue(card.rank)).sort((a, b) => a - b);
  const suits = cards.map((card) => card.suit);
  const countByValue = new Map();
  for (const value of values) {
    countByValue.set(value, (countByValue.get(value) || 0) + 1);
  }

  const counts = [...countByValue.values()].sort((a, b) => b - a);
  const uniqueValues = [...new Set(values)];
  const isFlush = new Set(suits).size === 1;

  let isStraight = false;
  if (uniqueValues.length === 5) {
    isStraight = uniqueValues[4] - uniqueValues[0] === 4;
    const wheel = [2, 3, 4, 5, 14];
    if (!isStraight && wheel.every((value, index) => uniqueValues[index] === value)) {
      isStraight = true;
    }
  }

  const isRoyal = isStraight && isFlush && values.join(",") === "10,11,12,13,14";
  if (isRoyal) return HAND_TYPES.ROYAL_FLUSH;
  if (isStraight && isFlush) return HAND_TYPES.STRAIGHT_FLUSH;
  if (counts[0] === 4) return HAND_TYPES.FOUR_KIND;
  if (counts[0] === 3 && counts[1] === 2) return HAND_TYPES.FULL_HOUSE;
  if (isFlush) return HAND_TYPES.FLUSH;
  if (isStraight) return HAND_TYPES.STRAIGHT;
  if (counts[0] === 3) return HAND_TYPES.THREE_KIND;
  if (counts[0] === 2 && counts[1] === 2) return HAND_TYPES.TWO_PAIR;
  if (counts[0] === 2) return HAND_TYPES.PAIR;
  return HAND_TYPES.HIGH_CARD;
}

function clearSelection() {
  state.selected.clear();
}

function replenishHand() {
  const needed = Math.max(0, 8 - state.hand.length);
  if (needed > 0) drawCards(needed);
}

function toggleSelection(index) {
  if (state.selected.has(index)) {
    state.selected.delete(index);
  } else {
    if (state.selected.size >= 5) {
      setMessage("You can only select up to 5 cards.");
      return;
    }
    state.selected.add(index);
  }
  render();
}

function removeSelectedCards() {
  const selectedIndices = [...state.selected].sort((a, b) => b - a);
  const chosen = selectedIndices.map((index) => state.hand[index]);
  for (const index of selectedIndices) {
    state.hand.splice(index, 1);
  }
  clearSelection();
  replenishHand();
  return chosen;
}

function setMessage(message) {
  ui.message.textContent = message;
}

function nextAnte() {
  state.ante += 1;
  state.score = 0;
  state.hands = 4;
  state.discards = 2;
  state.deck = buildDeck();
  state.hand = [];
  drawCards(8);
  clearSelection();
  setMessage(`Blind cleared! Welcome to Ante ${state.ante}.`);
}

function endRun(message) {
  state.gameOver = true;
  setMessage(`${message} Click New Run to play again.`);
}

function playSelected() {
  if (state.gameOver) return;
  if (state.hands <= 0) return;

  const chosen = [...state.selected].map((index) => state.hand[index]);
  if (chosen.length !== 5) {
    setMessage("Select exactly 5 cards to play.");
    return;
  }

  const handType = evaluateHand(chosen);
  const handScore = handType.chips * handType.mult;
  state.score += handScore;
  state.hands -= 1;
  removeSelectedCards();

  if (state.score >= targetScore()) {
    nextAnte();
  } else if (state.hands === 0) {
    endRun("You busted this blind.");
  } else {
    setMessage(`${handType.label}! +${handScore} (${handType.chips} ×${handType.mult}).`);
  }

  render();
}

function discardSelected() {
  if (state.gameOver) return;
  if (state.discards <= 0) {
    setMessage("No discards left this ante.");
    return;
  }

  if (state.selected.size === 0) {
    setMessage("Select at least 1 card to discard.");
    return;
  }

  removeSelectedCards();
  state.discards -= 1;
  setMessage("Discarded selected cards.");
  render();
}

function getCardImageSrc(card) {
  const rankMap = {
    2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8', 9: '9', 10: '10',
    J: 'jack', Q: 'queen', K: 'king', A: 'ace'
  };
  const suitMap = {
    '♠': 'spades', '♥': 'hearts', '♦': 'diamonds', '♣': 'clubs'
  };
  const rankName = rankMap[card.rank];
  const suitName = suitMap[card.suit];
  return `assets/cards/${rankName}_of_${suitName}.svg`;
}

function render() {
  ui.ante.textContent = String(state.ante);
  ui.target.textContent = String(targetScore());
  ui.score.textContent = String(state.score);
  ui.hands.textContent = String(state.hands);
  ui.discards.textContent = String(state.discards);
  ui.playBtn.disabled = state.gameOver;
  ui.discardBtn.disabled = state.gameOver;

  ui.hand.innerHTML = "";
  state.hand.forEach((card, index) => {
    const button = document.createElement("button");
    button.className = `card ${state.selected.has(index) ? "selected" : ""}`;
    button.type = "button";
    button.innerHTML = `<img src="${getCardImageSrc(card)}" alt="${card.rank}${card.suit}">`;
    button.addEventListener("click", () => toggleSelection(index));
    ui.hand.appendChild(button);
  });
}

function newRun() {
  state.ante = 1;
  state.score = 0;
  state.hands = 4;
  state.discards = 2;
  state.deck = buildDeck();
  state.hand = [];
  clearSelection();
  state.gameOver = false;
  drawCards(8);
  setMessage("Select up to 5 cards and play a poker hand.");
  render();
}

// Exports for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { SUITS, RANKS, HAND_TYPES, state, buildDeck, rankToValue, evaluateHand, getCardImageSrc, newRun, playSelected, discardSelected, toggleSelection };
}

if (typeof document !== 'undefined' && document.getElementById) {
  ui.playBtn.addEventListener("click", playSelected);
  ui.discardBtn.addEventListener("click", discardSelected);
  ui.newRunBtn.addEventListener("click", newRun);

  newRun();
}
