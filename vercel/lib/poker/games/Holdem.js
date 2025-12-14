/**
 * Texas Hold'em Poker Game Implementation
 *
 * Implements the rules and logic for Texas Hold'em poker
 */
const Card = require('../Card');
const Deck = require('../Deck');
const HandEvaluator = require('../HandEvaluator');

class TexasHoldem {
  /**
   * Create a new Texas Hold'em game
   * @param {Object} options - Game options
   */
  constructor(options = {}) {
    this.players = [];
    this.deck = null;
    this.communityCards = [];
    this.pot = 0;
    this.currentBet = 0;
    this.smallBlind = options.smallBlind || 10;
    this.bigBlind = options.bigBlind || 20;
    this.ante = options.ante || 0;
    this.currentPlayerIndex = 0;
    this.gameState = 'waiting'; // waiting, preflop, flop, turn, river, showdown
    this.buttonPosition = 0; // Dealer button position
    this.bettingRound = 0;
    this.lastRaiser = null;
    this.playerActions = [];
    this.winners = [];
    this.sidePots = [];
    this.gameHistory = [];
  }

  /**
   * Add a player to the game
   * @param {Object} player - Player object with id, name, and chips
   */
  addPlayer(player) {
    this.players.push({
      ...player,
      hand: [],
      chipsInPot: 0,
      hasActed: false,
      isAllIn: false,
      isFolded: false,
      lastAction: null
    });
  }

  /**
   * Start a new game
   */
  startGame() {
    if (this.players.length < 2) {
      throw new Error('Not enough players to start game');
    }

    // Reset game state
    this.communityCards = [];
    this.pot = 0;
    this.currentBet = this.bigBlind;
    this.gameState = 'preflop';
    this.bettingRound = 0;
    this.lastRaiser = null;
    this.playerActions = [];
    this.winners = [];
    this.sidePots = [];
    this.currentPlayerIndex = this._getNextPlayerIndex(this.buttonPosition);

    // Move dealer button
    this.buttonPosition = (this.buttonPosition + 1) % this.players.length;

    // Reset player states
    this.players.forEach(player => {
      player.hand = [];
      player.chipsInPot = 0;
      player.hasActed = false;
      player.isAllIn = false;
      player.isFolded = false;
      player.lastAction = null;
    });

    // Create and shuffle new deck
    this.deck = Deck.createStandard();

    // Post blinds
    this._postBlinds();

    // Deal hole cards
    this._dealHoleCards();

    // Start first betting round
    this.gameState = 'preflop';
    this._startBettingRound();

    return this._getGameState();
  }

  /**
   * Post small and big blinds
   */
  _postBlinds() {
    const smallBlindPos = this._getNextPlayerIndex(this.buttonPosition);
    const bigBlindPos = this._getNextPlayerIndex(smallBlindPos);

    // Post small blind
    const smallBlindPlayer = this.players[smallBlindPos];
    const smallBlindAmount = Math.min(smallBlindPlayer.chips, this.smallBlind);
    smallBlindPlayer.chips -= smallBlindAmount;
    smallBlindPlayer.chipsInPot += smallBlindAmount;
    smallBlindPlayer.lastAction = 'small_blind';
    this.pot += smallBlindAmount;

    // Post big blind
    const bigBlindPlayer = this.players[bigBlindPos];
    const bigBlindAmount = Math.min(bigBlindPlayer.chips, this.bigBlind);
    bigBlindPlayer.chips -= bigBlindAmount;
    bigBlindPlayer.chipsInPot += bigBlindAmount;
    bigBlindPlayer.lastAction = 'big_blind';
    this.pot += bigBlindAmount;
    this.currentBet = bigBlindAmount;

    // Mark blinds as having acted
    smallBlindPlayer.hasActed = true;
    bigBlindPlayer.hasActed = true;

    // Record actions
    this.playerActions.push({
      playerId: smallBlindPlayer.id,
      action: 'small_blind',
      amount: smallBlindAmount
    });

    this.playerActions.push({
      playerId: bigBlindPlayer.id,
      action: 'big_blind',
      amount: bigBlindAmount
    });
  }

  /**
   * Deal hole cards to players
   */
  _dealHoleCards() {
    for (let i = 0; i < this.players.length; i++) {
      const player = this.players[i];
      player.hand = [
        this.deck.deal(),
        this.deck.deal()
      ];
    }
  }

  /**
   * Start a betting round
   */
  _startBettingRound() {
    this.bettingRound++;
    this.players.forEach(player => {
      if (!player.isFolded && !player.isAllIn) {
        player.hasActed = false;
      }
    });

    // Set current player to next active player after big blind
    const bigBlindPos = this._getNextPlayerIndex(this.buttonPosition);
    this.currentPlayerIndex = this._getNextPlayerIndex(bigBlindPos);

    // Skip to next player if current player is all-in or folded
    while (this.players[this.currentPlayerIndex].isFolded ||
           this.players[this.currentPlayerIndex].isAllIn) {
      this.currentPlayerIndex = this._getNextPlayerIndex(this.currentPlayerIndex);
    }
  }

  /**
   * Deal the flop (first 3 community cards)
   */
  dealFlop() {
    if (this.gameState !== 'preflop') {
      throw new Error('Cannot deal flop in current game state');
    }

    // Burn a card
    this.deck.burn();

    // Deal 3 community cards
    this.communityCards = [
      this.deck.deal(),
      this.deck.deal(),
      this.deck.deal()
    ];

    this.gameState = 'flop';
    this._startBettingRound();

    return this._getGameState();
  }

  /**
   * Deal the turn (4th community card)
   */
  dealTurn() {
    if (this.gameState !== 'flop') {
      throw new Error('Cannot deal turn in current game state');
    }

    // Burn a card
    this.deck.burn();

    // Deal turn card
    this.communityCards.push(this.deck.deal());

    this.gameState = 'turn';
    this._startBettingRound();

    return this._getGameState();
  }

  /**
   * Deal the river (5th community card)
   */
  dealRiver() {
    if (this.gameState !== 'turn') {
      throw new Error('Cannot deal river in current game state');
    }

    // Burn a card
    this.deck.burn();

    // Deal river card
    this.communityCards.push(this.deck.deal());

    this.gameState = 'river';
    this._startBettingRound();

    return this._getGameState();
  }

  /**
   * Player makes a bet
   * @param {string} playerId - Player ID
   * @param {number} amount - Bet amount
   */
  bet(playerId, amount) {
    const player = this._getPlayerById(playerId);
    if (!player || player.isFolded || player.isAllIn) {
      throw new Error('Invalid player or player cannot act');
    }

    if (this.players[this.currentPlayerIndex].id !== playerId) {
      throw new Error('Not this player\'s turn');
    }

    // Minimum bet is the current bet amount
    const minBet = this.currentBet - player.chipsInPot;
    if (amount < minBet) {
      throw new Error(`Minimum bet is ${minBet}`);
    }

    // Player can't bet more than they have
    const betAmount = Math.min(amount, player.chips);
    player.chips -= betAmount;
    player.chipsInPot += betAmount;
    this.pot += betAmount;

    // Update current bet if this is a raise
    if (betAmount > (this.currentBet - player.chipsInPot + betAmount)) {
      this.currentBet = player.chipsInPot;
      this.lastRaiser = player.id;
    }

    player.hasActed = true;
    player.lastAction = 'bet';

    // Record action
    this.playerActions.push({
      playerId: player.id,
      action: 'bet',
      amount: betAmount
    });

    // Check if betting round is complete
    if (this._isBettingRoundComplete()) {
      this._endBettingRound();
    } else {
      this._moveToNextPlayer();
    }

    return this._getGameState();
  }

  /**
   * Player checks
   * @param {string} playerId - Player ID
   */
  check(playerId) {
    const player = this._getPlayerById(playerId);
    if (!player || player.isFolded || player.isAllIn) {
      throw new Error('Invalid player or player cannot act');
    }

    if (this.players[this.currentPlayerIndex].id !== playerId) {
      throw new Error('Not this player\'s turn');
    }

    // Can only check if no bet to call
    if (player.chipsInPot < this.currentBet) {
      throw new Error('Cannot check, must call or raise');
    }

    player.hasActed = true;
    player.lastAction = 'check';

    // Record action
    this.playerActions.push({
      playerId: player.id,
      action: 'check'
    });

    // Check if betting round is complete
    if (this._isBettingRoundComplete()) {
      this._endBettingRound();
    } else {
      this._moveToNextPlayer();
    }

    return this._getGameState();
  }

  /**
   * Player calls
   * @param {string} playerId - Player ID
   */
  call(playerId) {
    const player = this._getPlayerById(playerId);
    if (!player || player.isFolded || player.isAllIn) {
      throw new Error('Invalid player or player cannot act');
    }

    if (this.players[this.currentPlayerIndex].id !== playerId) {
      throw new Error('Not this player\'s turn');
    }

    // Calculate call amount
    const callAmount = this.currentBet - player.chipsInPot;
    if (callAmount <= 0) {
      throw new Error('Nothing to call');
    }

    // Player can't call more than they have
    const actualCallAmount = Math.min(callAmount, player.chips);
    player.chips -= actualCallAmount;
    player.chipsInPot += actualCallAmount;
    this.pot += actualCallAmount;

    // Check if player is all-in
    if (player.chips === 0 && player.chipsInPot < this.currentBet) {
      player.isAllIn = true;
    }

    player.hasActed = true;
    player.lastAction = 'call';

    // Record action
    this.playerActions.push({
      playerId: player.id,
      action: 'call',
      amount: actualCallAmount
    });

    // Check if betting round is complete
    if (this._isBettingRoundComplete()) {
      this._endBettingRound();
    } else {
      this._moveToNextPlayer();
    }

    return this._getGameState();
  }

  /**
   * Player folds
   * @param {string} playerId - Player ID
   */
  fold(playerId) {
    const player = this._getPlayerById(playerId);
    if (!player || player.isFolded || player.isAllIn) {
      throw new Error('Invalid player or player cannot act');
    }

    if (this.players[this.currentPlayerIndex].id !== playerId) {
      throw new Error('Not this player\'s turn');
    }

    player.isFolded = true;
    player.hasActed = true;
    player.lastAction = 'fold';

    // Record action
    this.playerActions.push({
      playerId: player.id,
      action: 'fold'
    });

    // Check if betting round is complete
    if (this._isBettingRoundComplete()) {
      this._endBettingRound();
    } else {
      this._moveToNextPlayer();
    }

    return this._getGameState();
  }

  /**
   * Check if betting round is complete
   */
  _isBettingRoundComplete() {
    // All active players have acted
    const activePlayers = this.players.filter(p => !p.isFolded && !p.isAllIn);
    const haveActed = activePlayers.every(p => p.hasActed);

    // If all but one player has folded
    const foldedPlayers = this.players.filter(p => p.isFolded);
    if (foldedPlayers.length === this.players.length - 1) {
      return true;
    }

    return haveActed;
  }

  /**
   * End the current betting round
   */
  _endBettingRound() {
    // Check if we need to proceed to next street
    switch (this.gameState) {
      case 'preflop':
        this.dealFlop();
        break;
      case 'flop':
        this.dealTurn();
        break;
      case 'turn':
        this.dealRiver();
        break;
      case 'river':
        this._determineWinners();
        break;
    }
  }

  /**
   * Determine winners and distribute pot
   */
  _determineWinners() {
    // Find players who haven't folded
    const activePlayers = this.players.filter(p => !p.isFolded);

    if (activePlayers.length === 0) {
      throw new Error('No active players to determine winners');
    }

    // If only one player remains, they win
    if (activePlayers.length === 1) {
      const winner = activePlayers[0];
      winner.chips += this.pot;
      this.winners = [winner];
      this.gameState = 'showdown';
      return;
    }

    // Evaluate hands for each active player
    const handEvaluations = activePlayers.map(player => {
      // Combine player's hand with community cards
      const allCards = [...player.hand, ...this.communityCards];

      // Find the best 5-card hand
      const bestHand = this._findBestHand(allCards);

      return {
        playerId: player.id,
        player: player,
        hand: bestHand.cards,
        evaluation: bestHand.evaluation
      };
    });

    // Sort by hand strength (highest first)
    handEvaluations.sort((a, b) =>
      HandEvaluator.compareHands(b.evaluation, a.evaluation));

    // Group players by hand strength
    const winningHand = handEvaluations[0].evaluation;
    const winners = handEvaluations.filter(
      handEval => HandEvaluator.compareHands(handEval.evaluation, winningHand) === 0
    );

    // Distribute pot
    const potPerWinner = Math.floor(this.pot / winners.length);
    const remainder = this.pot % winners.length;

    winners.forEach((winner, index) => {
      const winAmount = potPerWinner + (index === 0 ? remainder : 0);
      winner.player.chips += winAmount;

      this.winners.push({
        playerId: winner.playerId,
        player: winner.player,
        hand: winner.hand,
        winAmount: winAmount,
        handName: winner.evaluation.handName
      });
    });

    this.gameState = 'showdown';
  }

  /**
   * Find the best 5-card hand from 7 cards
   */
  _findBestHand(cards) {
    if (cards.length < 5) {
      throw new Error('Not enough cards to form a hand');
    }

    // Generate all possible 5-card combinations
    const combinations = this._generateCombinations(cards, 5);

    // Evaluate each combination and find the best one
    let bestHand = null;
    let bestEvaluation = null;

    for (const combo of combinations) {
      const evaluation = HandEvaluator.evaluateHand(combo);
      if (!bestEvaluation || HandEvaluator.compareHands(evaluation, bestEvaluation) > 0) {
        bestHand = combo;
        bestEvaluation = evaluation;
      }
    }

    return { cards: bestHand, evaluation: bestEvaluation };
  }

  /**
   * Generate all combinations of size n from array
   */
  _generateCombinations(array, n) {
    if (n > array.length) return [];

    const result = [];

    function combine(start, current) {
      if (current.length === n) {
        result.push([...current]);
        return;
      }

      for (let i = start; i < array.length; i++) {
        current.push(array[i]);
        combine(i + 1, current);
        current.pop();
      }
    }

    combine(0, []);
    return result;
  }

  /**
   * Move to the next active player
   */
  _moveToNextPlayer() {
    let nextIndex = this._getNextPlayerIndex(this.currentPlayerIndex);

    // Skip folded and all-in players
    while (this.players[nextIndex].isFolded || this.players[nextIndex].isAllIn) {
      nextIndex = this._getNextPlayerIndex(nextIndex);

      // If we've looped around, end the betting round
      if (nextIndex === this.currentPlayerIndex) {
        this._endBettingRound();
        return;
      }
    }

    this.currentPlayerIndex = nextIndex;
  }

  /**
   * Get next player index (circular)
   */
  _getNextPlayerIndex(currentIndex) {
    return (currentIndex + 1) % this.players.length;
  }

  /**
   * Get player by ID
   */
  _getPlayerById(playerId) {
    return this.players.find(p => p.id === playerId);
  }

  /**
   * Get current game state
   */
  _getGameState() {
    return {
      gameState: this.gameState,
      players: this.players.map(p => ({
        id: p.id,
        name: p.name,
        chips: p.chips,
        chipsInPot: p.chipsInPot,
        hand: p.hand.map(c => c.toString()),
        hasActed: p.hasActed,
        isFolded: p.isFolded,
        isAllIn: p.isAllIn,
        lastAction: p.lastAction
      })),
      communityCards: this.communityCards.map(c => c.toString()),
      pot: this.pot,
      currentBet: this.currentBet,
      currentPlayerIndex: this.currentPlayerIndex,
      buttonPosition: this.buttonPosition,
      playerActions: this.playerActions,
      winners: this.winners,
      smallBlind: this.smallBlind,
      bigBlind: this.bigBlind,
      ante: this.ante
    };
  }
}

module.exports = TexasHoldem;