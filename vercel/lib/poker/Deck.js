/**
 * Poker Deck Class
 *
 * Represents a deck of playing cards with shuffling and dealing capabilities
 */
const Card = require('./Card');

class Deck {
  /**
   * Create a new Deck
   * @param {boolean} includeJokers - Whether to include jokers in the deck
   */
  constructor(includeJokers = false) {
    this.cards = [];
    this.discardPile = [];
    this.includeJokers = includeJokers;
    this.initialize();
  }

  /**
   * Initialize the deck with standard cards
   */
  initialize() {
    this.cards = [];

    // Create standard 52 cards
    for (const suit of Card.SUITS) {
      for (const rank of Card.RANKS) {
        const cardId = `${rank[0]}${suit[0]}_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
        this.cards.push(new Card(suit, rank, cardId));
      }
    }

    // Add jokers if requested
    if (this.includeJokers) {
      this.cards.push(new Card('joker', 'red', `RED_JOKER_${Date.now()}`));
      this.cards.push(new Card('joker', 'black', `BLACK_JOKER_${Date.now()}`));
    }
  }

  /**
   * Shuffle the deck using Fisher-Yates algorithm
   */
  shuffle() {
    for (let i = this.cards.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.cards[i], this.cards[j]] = [this.cards[j], this.cards[i]];
    }
    return this;
  }

  /**
   * Deal a single card from the top of the deck
   * @returns {Card|null} The dealt card or null if deck is empty
   */
  deal() {
    if (this.cards.length === 0) {
      return null;
    }
    return this.cards.pop();
  }

  /**
   * Deal multiple cards
   * @param {number} count - Number of cards to deal
   * @returns {Card[]} Array of dealt cards
   */
  dealMultiple(count) {
    const dealtCards = [];
    for (let i = 0; i < count && this.cards.length > 0; i++) {
      dealtCards.push(this.deal());
    }
    return dealtCards;
  }

  /**
   * Burn a card (move to discard pile)
   * @returns {Card|null} The burned card or null if deck is empty
   */
  burn() {
    const burnedCard = this.deal();
    if (burnedCard) {
      this.discardPile.push(burnedCard);
    }
    return burnedCard;
  }

  /**
   * Get number of cards remaining in deck
   * @returns {number} Cards remaining
   */
  remaining() {
    return this.cards.length;
  }

  /**
   * Reset the deck (move discard pile back and shuffle)
   */
  reset() {
    this.cards = [...this.cards, ...this.discardPile];
    this.discardPile = [];
    this.shuffle();
    return this;
  }

  /**
   * Get all cards in the deck
   * @returns {Card[]} All cards
   */
  getAllCards() {
    return [...this.cards];
  }

  /**
   * Get discard pile
   * @returns {Card[]} Discarded cards
   */
  getDiscardPile() {
    return [...this.discardPile];
  }

  /**
   * Create a standard deck
   * @param {boolean} includeJokers - Include jokers
   * @returns {Deck} New deck instance
   */
  static createStandard(includeJokers = false) {
    return new Deck(includeJokers).shuffle();
  }
}

module.exports = Deck;