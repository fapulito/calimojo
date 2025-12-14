/**
 * Poker Card Class - Ported from Perl FB::Poker::Card
 *
 * Represents a playing card with suit, rank, and additional properties
 */
class Card {
  /**
   * Create a new Card
   * @param {string} suit - Card suit (hearts, diamonds, clubs, spades)
   * @param {string} rank - Card rank (2-10, J, Q, K, A)
   * @param {string} id - Unique card identifier
   */
  constructor(suit, rank, id) {
    this.suit = suit;
    this.rank = rank;
    this.id = id;
    this.up_flag = true; // Card is face up by default
    this.wild_flag = false; // Not wild by default
  }

  /**
   * Clone the card (create a copy)
   * @returns {Card} New card instance with same properties
   */
  clone() {
    const clonedCard = new Card(this.suit, this.rank, this.id);
    clonedCard.up_flag = this.up_flag;
    clonedCard.wild_flag = this.wild_flag;
    return clonedCard;
  }

  /**
   * Check if card is wild
   * @returns {boolean} True if card is wild
   */
  isWild() {
    return this.wild_flag;
  }

  /**
   * Make card wild
   */
  makeWild() {
    this.wild_flag = true;
  }

  /**
   * Remove wild status
   */
  clearWild() {
    this.wild_flag = false;
  }

  /**
   * Flip card (change up/down status)
   */
  flip() {
    this.up_flag = !this.up_flag;
  }

  /**
   * Get card as string representation
   * @returns {string} Card string (e.g., "Ah" for Ace of Hearts)
   */
  toString() {
    const rankChar = this.rank.length === 1 ? this.rank : this.rank[0];
    const suitChar = this.suit[0].toUpperCase();
    return `${rankChar}${suitChar}`;
  }

  /**
   * Get card as JSON
   * @returns {Object} Card properties as JSON
   */
  toJSON() {
    return {
      suit: this.suit,
      rank: this.rank,
      id: this.id,
      up_flag: this.up_flag,
      wild_flag: this.wild_flag
    };
  }

  /**
   * Create card from string (e.g., "Ah" -> Ace of Hearts)
   * @param {string} cardString - Card string representation
   * @returns {Card} New card instance
   */
  static fromString(cardString) {
    if (!cardString || cardString.length < 2) {
      throw new Error('Invalid card string');
    }

    // Extract rank and suit
    const rank = cardString.slice(0, -1);
    const suitChar = cardString.slice(-1).toLowerCase();

    // Map suit characters to full names
    const suitMap = {
      h: 'hearts',
      d: 'diamonds',
      c: 'clubs',
      s: 'spades'
    };

    const suit = suitMap[suitChar] || 'hearts';
    const id = `${cardString}_${Date.now()}`;

    return new Card(suit, rank, id);
  }
}

// Standard card suits and ranks
Card.SUITS = ['hearts', 'diamonds', 'clubs', 'spades'];
Card.RANKS = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];

module.exports = Card;