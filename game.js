const SUITS = ["♠", "♥", "♦", "♣"];
const RANKS = [2, 3, 4, 5, 6, 7, 8, 9, 10, "J", "Q", "K", "A"];
const ANTE_TARGETS = [200, 400, 700];
const THEME_STORAGE_KEY = "balatrin-theme";
const STARTING_HANDS = 4;
const STARTING_DISCARDS = 3;

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

const JOKERS = {
  JOKER: { name: "Joker", rarity: "common", formula: "+4 Mult", effect: " +4 Mult", image: "Joker.png", ability: (hand, handType) => ({ mult: 4 }) },
  GREEDY_JOKER: { name: "Greedy Joker", rarity: "uncommon", formula: "+4 Mult if at least one Diamond is played", effect: " +4 Mult if played hand has a Diamond", image: "Joker2.png", ability: (hand, handType) => {
    const hasDiamond = hand.some(card => card.suit === '♦');
    return hasDiamond ? { mult: 4 } : {};
  }},
  PAIR_JOKER: { name: "Pair Joker", rarity: "rare", formula: "+2 Mult x number of pairs in played cards", effect: " +2 Mult for each Pair in hand", image: "Joker.png", ability: (hand, handType) => {
    const ranks = hand.map(card => card.rank);
    const pairs = ranks.filter(rank => ranks.filter(r => r === rank).length === 2).length / 2;
    return { mult: pairs * 2 };
  }},
};

const state = {
  ante: 1,
  score: 0,
  hands: STARTING_HANDS,
  discards: STARTING_DISCARDS,
  deck: [],
  hand: [],
  selected: new Set(),
  jokers: [],
  gameOver: false,
};

let disableAnimation = false;
let handMutationId = 0;
let lastRenderedHandMutationId = -1;

if (typeof document !== 'undefined' && document.getElementById) {
  ui = {
    ante: document.getElementById("ante"),
    target: document.getElementById("target"),
    score: document.getElementById("score"),
    hands: document.getElementById("hands"),
    discards: document.getElementById("discards"),
    hand: document.getElementById("hand"),
    jokers: document.getElementById("jokers"),
    scorePopups: document.getElementById("score-popups"),
    calculation: document.getElementById("calculation"),
    message: document.getElementById("message"),
    previewHand: document.getElementById("preview-hand"),
    previewBase: document.getElementById("preview-base"),
    previewJokers: document.getElementById("preview-jokers"),
    previewTotal: document.getElementById("preview-total"),
    pressureLabel: document.getElementById("pressure-label"),
    pressureFill: document.getElementById("pressure-fill"),
    playBtn: document.getElementById("play-btn"),
    discardBtn: document.getElementById("discard-btn"),
    newRunBtn: document.getElementById("new-run-btn"),
    addJokerBtn: document.getElementById("add-joker-btn"),
    setHandBtn: document.getElementById("set-hand-btn"),
    themeToggleBtn: document.getElementById("theme-toggle-btn"),
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

function bumpHandMutation() {
  handMutationId += 1;
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
  if (count > 0) {
    bumpHandMutation();
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
  if (cards.length === 0) return HAND_TYPES.HIGH_CARD;

  const values = cards.map((card) => rankToValue(card.rank)).sort((a, b) => a - b);
  const suits = cards.map((card) => card.suit);
  const countByValue = new Map();
  for (const value of values) {
    countByValue.set(value, (countByValue.get(value) || 0) + 1);
  }

  const counts = [...countByValue.values()].sort((a, b) => b - a);
  const uniqueValues = [...new Set(values)];
  const isFiveCardHand = cards.length === 5;
  const isFlush = isFiveCardHand && new Set(suits).size === 1;

  let isStraight = false;
  if (isFiveCardHand && uniqueValues.length === 5) {
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
  if (selectedIndices.length > 0) {
    bumpHandMutation();
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
  state.hands = STARTING_HANDS;
  state.discards = STARTING_DISCARDS;
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

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function animateSelectedCardsOut(mode) {
  if (disableAnimation) return;
  const selectedIndices = [...state.selected];
  if (selectedIndices.length === 0) return;
  const cardButtons = ui.hand ? Array.from(ui.hand.querySelectorAll(".card")) : [];
  selectedIndices.forEach((index, order) => {
    const cardButton = cardButtons[index];
    if (cardButton) {
      cardButton.classList.add("card-exit", mode === "discard" ? "discard" : "play");
      cardButton.style.animationDelay = `${order * 45}ms`;
    }
  });
  await sleep(280 + selectedIndices.length * 45);
}

function showScorePopup(scoreDelta) {
  if (!ui.scorePopups || disableAnimation) return;
  const popup = document.createElement("div");
  popup.className = "score-popup";
  popup.textContent = `+${scoreDelta}`;
  ui.scorePopups.appendChild(popup);
  popup.addEventListener("animationend", () => popup.remove(), { once: true });
}

function formatJokerBonus(effect) {
  const parts = [];
  if (effect.chips) parts.push(`+${effect.chips} chips`);
  if (effect.mult) parts.push(`+${effect.mult} mult`);
  return parts.join(", ") || "No bonus";
}

function calculateHandProjection(chosen) {
  if (chosen.length === 0) {
    return {
      chosen,
      handType: null,
      baseChips: 0,
      baseMult: 0,
      baseTotal: 0,
      total: 0,
      jokerDetails: [],
    };
  }

  const handType = evaluateHand(chosen);
  const baseChips = handType.chips;
  const baseMult = handType.mult;
  let currentChips = baseChips;
  let currentMult = baseMult;
  const jokerDetails = [];

  for (const jokerKey of state.jokers) {
    const joker = JOKERS[jokerKey];
    if (!joker) continue;
    const effect = joker.ability(chosen, handType);
    currentChips += effect.chips || 0;
    currentMult += effect.mult || 0;
    jokerDetails.push({ jokerKey, effect });
  }

  return {
    chosen,
    handType,
    baseChips,
    baseMult,
    baseTotal: baseChips * baseMult,
    total: currentChips * currentMult,
    jokerDetails,
  };
}

function updatePreviewHud(projection) {
  if (!ui.previewHand || !ui.previewBase || !ui.previewJokers || !ui.previewTotal) return;
  if (!projection.handType) {
    ui.previewHand.textContent = "No cards selected";
    ui.previewBase.textContent = "Base: -";
    ui.previewJokers.textContent = "Jokers: -";
    ui.previewTotal.textContent = "Projected: +0";
    return;
  }

  ui.previewHand.textContent = `${projection.chosen.length} selected • ${projection.handType.label}`;
  ui.previewBase.textContent = `Base: ${projection.baseChips} x ${projection.baseMult} = ${projection.baseTotal}`;
  const jokerText = projection.jokerDetails.length > 0
    ? projection.jokerDetails.map((detail) => {
      const joker = JOKERS[detail.jokerKey];
      return `${joker.name} (${formatJokerBonus(detail.effect)})`;
    }).join(" | ")
    : "No jokers";
  ui.previewJokers.textContent = `Jokers: ${jokerText}`;
  ui.previewTotal.textContent = `Projected: +${projection.total}`;
}

function updateBlindPressure() {
  if (!ui.pressureFill || !ui.pressureLabel) return;
  const target = targetScore();
  const progress = Math.max(0, Math.min(state.score / target, 1));
  ui.pressureFill.style.width = `${progress * 100}%`;
  ui.pressureLabel.textContent = `${state.score} / ${target}`;
  ui.pressureFill.classList.remove("risk-low", "risk-mid", "risk-high");
  const nearFailure = state.hands <= 1 && progress < 0.9;
  const moderateRisk = state.hands <= 2 && progress < 0.65;
  if (nearFailure) {
    ui.pressureFill.classList.add("risk-high");
  } else if (moderateRisk) {
    ui.pressureFill.classList.add("risk-mid");
  } else {
    ui.pressureFill.classList.add("risk-low");
  }
}

async function animateCalculation(chosen, handType) {
  ui.calculation.style.display = 'block';
  ui.calculation.innerHTML = '';

  let currentChips = handType.chips;
  let currentMult = handType.mult;
  let totalScore = currentChips * currentMult;

  // Base
  ui.calculation.innerHTML += `${handType.label}: ${handType.chips} × ${handType.mult} = ${totalScore}<br>`;
  if (!disableAnimation) await sleep(500);

  // Jokers
  for (const jokerKey of state.jokers) {
    const joker = JOKERS[jokerKey];
    if (joker) {
      const effect = joker.ability(chosen, handType);
      if (effect.chips) {
        currentChips += effect.chips;
        totalScore = currentChips * currentMult;
        ui.calculation.innerHTML += `+ ${joker.name}: +${effect.chips} chips = ${currentChips} × ${currentMult} = ${totalScore}<br>`;
      }
      if (effect.mult) {
        currentMult += effect.mult;
        totalScore = currentChips * currentMult;
        ui.calculation.innerHTML += `+ ${joker.name}: +${effect.mult} mult = ${currentChips} × ${currentMult} = ${totalScore}<br>`;
      }
      if (!disableAnimation) await sleep(500);
    }
  }

  // Total
  ui.calculation.innerHTML += `<strong>Total: +${totalScore}</strong>`;
  if (!disableAnimation) await sleep(1000);

  // Hide and update
  ui.calculation.style.display = 'none';
  showScorePopup(totalScore);
  await animateSelectedCardsOut("play");
  state.score += totalScore;
  state.hands -= 1;
  removeSelectedCards();

  if (state.score >= targetScore()) {
    nextAnte();
  } else if (state.hands === 0) {
    endRun("You busted this blind.");
  } else {
    setMessage(`${handType.label}! +${totalScore}.`);
  }

  render();
}

function playSelected() {
  if (state.gameOver) return;
  if (state.hands <= 0) return;

  const chosen = [...state.selected].map((index) => state.hand[index]);
  if (chosen.length === 0) {
    setMessage("Select at least 1 card to play.");
    return;
  }

  const handType = evaluateHand(chosen);
  return animateCalculation(chosen, handType);
}

async function discardSelected() {
  if (state.gameOver) return;
  if (state.discards <= 0) {
    setMessage("No discards left this ante.");
    return;
  }

  if (state.selected.size === 0) {
    setMessage("Select at least 1 card to discard.");
    return;
  }

  await animateSelectedCardsOut("discard");
  removeSelectedCards();
  state.discards -= 1;
  setMessage("Discarded selected cards.");
  render();
}

function getTheme() {
  if (typeof document === "undefined") return "dark";
  return document.documentElement.dataset.theme || "dark";
}

function getSpriteSetPath() {
  return getTheme() === "light" ? "Cards/Cards" : "Cards/Cards_Dark";
}

function rankToSpriteToken(rank) {
  if (typeof rank === "number") return String(rank);
  return rank;
}

function getCardImageSrc(card) {
  const suitMap = {
    '♠': 'S',
    '♥': 'H',
    '♦': 'D',
    '♣': 'C'
  };
  const suitAbbr = suitMap[card.suit];
  return `${getSpriteSetPath()}/${suitAbbr}${rankToSpriteToken(card.rank)}.png`;
}

function getJokerImageSrc(joker) {
  return `${getSpriteSetPath()}/${joker.image}`;
}

function applyTheme(theme) {
  if (typeof document === "undefined") return;
  const nextTheme = theme === "light" ? "light" : "dark";
  document.documentElement.dataset.theme = nextTheme;
  try {
    window.localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
  } catch (error) {
    // Ignore storage restrictions in private/testing contexts.
  }
}

function toggleTheme() {
  const nextTheme = getTheme() === "dark" ? "light" : "dark";
  applyTheme(nextTheme);
  render();
}

function hydrateTheme() {
  if (typeof document === "undefined") return;
  let savedTheme = "dark";
  try {
    savedTheme = window.localStorage.getItem(THEME_STORAGE_KEY) || "dark";
  } catch (error) {
    savedTheme = "dark";
  }
  applyTheme(savedTheme);
}

function getJokerTooltipText(jokerKey, projection) {
  const joker = JOKERS[jokerKey];
  if (!joker) return "";
  const detail = projection.jokerDetails.find((entry) => entry.jokerKey === jokerKey);
  const currentBonus = detail ? formatJokerBonus(detail.effect) : "No bonus";
  return `${joker.name} (${joker.rarity})\nFormula: ${joker.formula}\nCurrent: ${currentBonus}`;
}

function render() {
  const chosen = [...state.selected].map((index) => state.hand[index]).filter(Boolean);
  const projection = calculateHandProjection(chosen);
  const shouldAnimateDeal = handMutationId !== lastRenderedHandMutationId;

  ui.ante.textContent = String(state.ante);
  ui.target.textContent = String(targetScore());
  ui.score.textContent = String(state.score);
  ui.hands.textContent = String(state.hands);
  ui.discards.textContent = String(state.discards);
  ui.playBtn.disabled = state.gameOver;
  ui.discardBtn.disabled = state.gameOver;
  if (ui.themeToggleBtn) {
    ui.themeToggleBtn.textContent = getTheme() === "dark" ? "Switch to Light" : "Switch to Dark";
  }
  updatePreviewHud(projection);
  updateBlindPressure();

  ui.hand.innerHTML = "";
  const midPoint = (state.hand.length - 1) / 2;
  state.hand.forEach((card, index) => {
    const offsetFromCenter = index - midPoint;
    const button = document.createElement("button");
    button.className = `card ${state.selected.has(index) ? "selected" : ""}`;
    if (shouldAnimateDeal && !disableAnimation) {
      button.classList.add("card-deal");
      button.style.animationDelay = `${index * 55}ms`;
    }
    button.style.setProperty("--fan-rotate", `${offsetFromCenter * 4.3}deg`);
    button.style.setProperty("--fan-lift", `${Math.abs(offsetFromCenter) * 2.4}px`);
    button.style.zIndex = String(index + 1);
    button.type = "button";
    button.innerHTML = `<img src="${getCardImageSrc(card)}" alt="${card.rank}${card.suit}">`;
    button.addEventListener("click", () => toggleSelection(index));
    ui.hand.appendChild(button);
  });
  lastRenderedHandMutationId = handMutationId;

  ui.jokers.innerHTML = "";
  state.jokers.forEach((jokerKey) => {
    const joker = JOKERS[jokerKey];
    if (joker) {
      const div = document.createElement("div");
      div.className = `joker rarity-${joker.rarity || "common"}`;
      div.title = getJokerTooltipText(jokerKey, projection);
      div.innerHTML = `<img src="${getJokerImageSrc(joker)}" alt="${joker.name}" onerror="this.style.display='none'"><strong>${joker.name}</strong><em>${joker.rarity || "common"}</em><span>${joker.effect}</span>`;
      ui.jokers.appendChild(div);
    }
  });
}

function newRun() {
  state.ante = 1;
  state.score = 0;
  state.hands = STARTING_HANDS;
  state.discards = STARTING_DISCARDS;
  state.deck = buildDeck();
  state.hand = [];
  state.jokers = [];
  clearSelection();
  state.gameOver = false;
  drawCards(8);
  setMessage("Select up to 5 cards and play a poker hand.");
  render();
}

function addJoker() {
  const jokerKeys = Object.keys(JOKERS);
  const randomJoker = jokerKeys[Math.floor(Math.random() * jokerKeys.length)];
  if (state.jokers.length < 5) {
    state.jokers.push(randomJoker);
    setMessage(`Added ${JOKERS[randomJoker].name}!`);
    render();
  } else {
    setMessage("Max 5 Jokers!");
  }
}

function setHandToRoyalFlush() {
  state.hand = [
    { rank: 10, suit: '♠' },
    { rank: 'J', suit: '♠' },
    { rank: 'Q', suit: '♠' },
    { rank: 'K', suit: '♠' },
    { rank: 'A', suit: '♠' },
    { rank: 2, suit: '♥' },
    { rank: 3, suit: '♥' },
    { rank: 4, suit: '♥' },
  ];
  bumpHandMutation();
  clearSelection();
  setMessage("Hand set to Royal Flush + extras!");
  render();
}

// Exports for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { SUITS, RANKS, HAND_TYPES, JOKERS, state, buildDeck, rankToValue, evaluateHand, getCardImageSrc, newRun, playSelected, discardSelected, toggleSelection, addJoker, setHandToRoyalFlush, animateCalculation, disableAnimation };
}

if (typeof document !== 'undefined' && document.getElementById) {
  hydrateTheme();
  ui.playBtn.addEventListener("click", playSelected);
  ui.discardBtn.addEventListener("click", discardSelected);
  ui.newRunBtn.addEventListener("click", newRun);
  ui.addJokerBtn.addEventListener("click", addJoker);
  ui.setHandBtn.addEventListener("click", setHandToRoyalFlush);
  if (ui.themeToggleBtn) {
    ui.themeToggleBtn.addEventListener("click", toggleTheme);
  }

  newRun();
}
