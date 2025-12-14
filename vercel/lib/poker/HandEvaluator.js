/**
 * Poker Hand Evaluator
 *
 * Evaluates poker hands and determines their strength
 * Supports standard poker hand rankings for Texas Hold'em, Omaha, etc.
 */
const Card = require('./Card');

class HandEvaluator {
  /**
   * Evaluate a poker hand
   * @param {Card[]} cards - Array of Card objects
   * @returns {Object} Hand evaluation result
   */
  static evaluateHand(cards) {
    if (!cards || cards.length === 0) {
      throw new Error('No cards provided for evaluation');
    }

    // Sort cards by rank for easier evaluation
    const sortedCards = this._sortCardsByRank(cards);

    // Check for each hand type in order of strength
    const handRank = this._evaluateHandType(sortedCards);

    // Calculate hand strength value
    const handValue = this._calculateHandValue(handRank, sortedCards);

    return {
      handName: handRank.name,
      handRank: handRank.rank,
      handValue: handValue,
      cards: sortedCards,
      description: this._getHandDescription(handRank, sortedCards)
    };
  }

  /**
   * Sort cards by rank (high to low)
   */
  static _sortCardsByRank(cards) {
    const rankOrder = {
      '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
      '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14
    };

    return [...cards].sort((a, b) => {
      const rankA = rankOrder[a.rank] || 0;
      const rankB = rankOrder[b.rank] || 0;
      return rankB - rankA; // Descending order
    });
  }

  /**
   * Evaluate hand type and return rank information
   */
  static _evaluateHandType(cards) {
    // Check for straight flush / royal flush
    const straightFlushInfo = this._checkStraightFlush(cards);
    if (straightFlushInfo) {
      return straightFlushInfo.isRoyal
        ? { name: 'Royal Flush', rank: 10 }
        : { name: 'Straight Flush', rank: 9 };
    }

    // Check for four of a kind
    const fourOfAKindInfo = this._checkFourOfAKind(cards);
    if (fourOfAKindInfo) {
      return { name: 'Four of a Kind', rank: 8, ...fourOfAKindInfo };
    }

    // Check for full house
    const fullHouseInfo = this._checkFullHouse(cards);
    if (fullHouseInfo) {
      return { name: 'Full House', rank: 7, ...fullHouseInfo };
    }

    // Check for flush
    if (this._checkFlush(cards)) {
      return { name: 'Flush', rank: 6 };
    }

    // Check for straight
    const straightInfo = this._checkStraight(cards);
    if (straightInfo) {
      return { name: 'Straight', rank: 5, ...straightInfo };
    }

    // Check for three of a kind
    const threeOfAKindInfo = this._checkThreeOfAKind(cards);
    if (threeOfAKindInfo) {
      return { name: 'Three of a Kind', rank: 4, ...threeOfAKindInfo };
    }

    // Check for two pair
    const twoPairInfo = this._checkTwoPair(cards);
    if (twoPairInfo) {
      return { name: 'Two Pair', rank: 3, ...twoPairInfo };
    }

    // Check for one pair
    const onePairInfo = this._checkOnePair(cards);
    if (onePairInfo) {
      return { name: 'One Pair', rank: 2, ...onePairInfo };
    }

    // High card
    return { name: 'High Card', rank: 1 };
  }

  /**
   * Check for straight flush or royal flush
   */
  static _checkStraightFlush(cards) {
    // Check if all cards have the same suit
    const firstSuit = cards[0].suit;
    const allSameSuit = cards.every(card => card.suit === firstSuit);
    if (!allSameSuit) return null;

    // Check for straight
    const straightInfo = this._checkStraight(cards);
    if (!straightInfo) return null;

    // Check if it's a royal flush (A-K-Q-J-10)
    const isRoyal = straightInfo.highRank === 14; // Ace high
    return { isRoyal, highRank: straightInfo.highRank };
  }

  /**
   * Check for four of a kind
   */
  static _checkFourOfAKind(cards) {
    const rankCounts = this._getRankCounts(cards);

    for (const rank in rankCounts) {
      if (rankCounts[rank] === 4) {
        const quadRank = parseInt(rank);
        // Find the kicker
        const kickerRank = Object.keys(rankCounts)
          .filter(r => r !== rank)
          .map(r => parseInt(r))
          .sort((a, b) => b - a)[0];

        return { quadRank, kickerRank };
      }
    }

    return null;
  }

  /**
   * Check for full house
   */
  static _checkFullHouse(cards) {
    const rankCounts = this._getRankCounts(cards);
    const counts = Object.values(rankCounts);

    // Full house has one triplet and one pair
    const hasTriplet = counts.some(c => c === 3);
    const hasPair = counts.some(c => c === 2);

    if (hasTriplet && hasPair) {
      // Find the triplet and pair ranks
      const tripletRank = Object.keys(rankCounts)
        .find(r => rankCounts[r] === 3);
      const pairRank = Object.keys(rankCounts)
        .find(r => rankCounts[r] === 2);

      return { tripletRank: parseInt(tripletRank), pairRank: parseInt(pairRank) };
    }

    return null;
  }

  /**
   * Check for flush
   */
  static _checkFlush(cards) {
    const firstSuit = cards[0].suit;
    return cards.every(card => card.suit === firstSuit);
  }

  /**
   * Check for straight
   */
  static _checkStraight(cards) {
    const rankOrder = {
      '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
      '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14
    };

    // Get unique ranks sorted numerically
    const uniqueRanks = [...new Set(cards.map(card => rankOrder[card.rank]))]
      .sort((a, b) => a - b);

    // Check for wheel straight (A-2-3-4-5)
    if (uniqueRanks.length >= 5) {
      const hasWheel = uniqueRanks.includes(14) &&
                      uniqueRanks.includes(2) &&
                      uniqueRanks.includes(3) &&
                      uniqueRanks.includes(4) &&
                      uniqueRanks.includes(5);

      if (hasWheel) {
        return { highRank: 5, isWheel: true }; // 5 is the high card for wheel
      }
    }

    // Check for regular straight
    for (let i = 0; i <= uniqueRanks.length - 5; i++) {
      const sequence = uniqueRanks.slice(i, i + 5);
      const isStraight = sequence.every((rank, index) =>
        index === 0 || rank === sequence[index - 1] + 1);

      if (isStraight) {
        return { highRank: sequence[4], isWheel: false };
      }
    }

    return null;
  }

  /**
   * Check for three of a kind
   */
  static _checkThreeOfAKind(cards) {
    const rankCounts = this._getRankCounts(cards);

    for (const rank in rankCounts) {
      if (rankCounts[rank] === 3) {
        const tripletRank = parseInt(rank);
        // Get kickers (remaining cards)
        const kickers = Object.keys(rankCounts)
          .filter(r => r !== rank)
          .map(r => parseInt(r))
          .sort((a, b) => b - a);

        return { tripletRank, kickers };
      }
    }

    return null;
  }

  /**
   * Check for two pair
   */
  static _checkTwoPair(cards) {
    const rankCounts = this._getRankCounts(cards);
    const pairs = Object.keys(rankCounts)
      .filter(rank => rankCounts[rank] === 2)
      .map(rank => parseInt(rank))
      .sort((a, b) => b - a);

    if (pairs.length >= 2) {
      // Get the highest pair and second highest pair
      const highPair = pairs[0];
      const lowPair = pairs[1];

      // Get kicker if available
      const kicker = Object.keys(rankCounts)
        .filter(r => rankCounts[r] === 1)
        .map(r => parseInt(r))
        .sort((a, b) => b - a)[0] || 0;

      return { highPair, lowPair, kicker };
    }

    return null;
  }

  /**
   * Check for one pair
   */
  static _checkOnePair(cards) {
    const rankCounts = this._getRankCounts(cards);

    for (const rank in rankCounts) {
      if (rankCounts[rank] === 2) {
        const pairRank = parseInt(rank);
        // Get kickers (remaining cards, sorted high to low)
        const kickers = Object.keys(rankCounts)
          .filter(r => r !== rank)
          .map(r => parseInt(r))
          .sort((a, b) => b - a);

        return { pairRank, kickers };
      }
    }

    return null;
  }

  /**
   * Get count of each rank in the hand
   */
  static _getRankCounts(cards) {
    const rankOrder = {
      '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
      '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14
    };

    const rankCounts = {};
    for (const card of cards) {
      const rank = rankOrder[card.rank] || 0;
      rankCounts[rank] = (rankCounts[rank] || 0) + 1;
    }
    return rankCounts;
  }

  /**
   * Calculate a numerical value for hand comparison
   */
  static _calculateHandValue(handRank, cards) {
    // Base value is hand rank (1-10) shifted left by 20 bits
    let handValue = handRank.rank << 20;

    // Add card-specific values based on hand type
    switch (handRank.name) {
      case 'Royal Flush':
      case 'Straight Flush':
        handValue += handRank.highRank << 16;
        break;

      case 'Four of a Kind':
        handValue += handRank.quadRank << 16;
        handValue += handRank.kickerRank << 12;
        break;

      case 'Full House':
        handValue += handRank.tripletRank << 16;
        handValue += handRank.pairRank << 12;
        break;

      case 'Flush':
      case 'Straight':
        // For flush/straight, use the high card
        handValue += handRank.highRank << 16;
        break;

      case 'Three of a Kind':
        handValue += handRank.tripletRank << 16;
        // Add kickers
        if (handRank.kickers && handRank.kickers.length > 0) {
          handValue += handRank.kickers[0] << 12;
          handValue += handRank.kickers[1] << 8;
        }
        break;

      case 'Two Pair':
        handValue += handRank.highPair << 16;
        handValue += handRank.lowPair << 12;
        handValue += (handRank.kicker || 0) << 8;
        break;

      case 'One Pair':
        handValue += handRank.pairRank << 16;
        // Add kickers
        if (handRank.kickers && handRank.kickers.length >= 3) {
          handValue += handRank.kickers[0] << 12;
          handValue += handRank.kickers[1] << 8;
          handValue += handRank.kickers[2] << 4;
        }
        break;

      case 'High Card': {
        // Use the top 5 cards
        const topCards = cards.slice(0, 5);
        for (let i = 0; i < topCards.length; i++) {
          const rankOrder = { '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
                             '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14 };
          const rankValue = rankOrder[topCards[i].rank] || 0;
          handValue += rankValue << (16 - i * 4);
        }
        break;
      }
    }

    return handValue;
  }

  /**
   * Get human-readable hand description
   */
  static _getHandDescription(handRank, cards) {
    // Cache rank counts to avoid repeated computation
    const rankCounts = this._getRankCounts(cards);

    switch (handRank.name) {
      case 'Royal Flush':
        return `Royal Flush (${cards[0].suit})`;

      case 'Straight Flush': {
        const rankOrder = { '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
                           '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14 };
        const highCard = Object.keys(rankOrder).find(
          key => rankOrder[key] === handRank.highRank);
        return `Straight Flush (${highCard} high, ${cards[0].suit})`;
      }

      case 'Four of a Kind': {
        const quadRank = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 4);
        const kickerRank = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 1);
        return `Four of a Kind (${quadRank}s with ${kickerRank} kicker)`;
      }

      case 'Full House': {
        const tripletRankKey = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 3);
        const pairRankKey = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 2);
        return `Full House (${tripletRankKey}s full of ${pairRankKey}s)`;
      }

      case 'Flush':
        return `Flush (${cards[0].suit}, ${cards[0].rank} high)`;

      case 'Straight': {
        const straightHighCard = Object.keys(rankCounts)
          .map(rank => parseInt(rank))
          .sort((a, b) => b - a)[0];
        const rankNames = { 14: 'A', 13: 'K', 12: 'Q', 11: 'J', 10: 'T', 9: '9', 8: '8',
                           7: '7', 6: '6', 5: '5', 4: '4', 3: '3', 2: '2' };
        const highCardName = rankNames[straightHighCard] || straightHighCard;
        return `Straight (${highCardName} high)`;
      }

      case 'Three of a Kind': {
        const tripletRank = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 3);
        return `Three of a Kind (${tripletRank}s)`;
      }

      case 'Two Pair': {
        const highPair = Object.keys(rankCounts)
          .filter(rank => rankCounts[rank] === 2)
          .map(rank => parseInt(rank))
          .sort((a, b) => b - a)[0];
        const lowPair = Object.keys(rankCounts)
          .filter(rank => rankCounts[rank] === 2)
          .map(rank => parseInt(rank))
          .sort((a, b) => b - a)[1];
        const rankNames2 = { 14: 'A', 13: 'K', 12: 'Q', 11: 'J', 10: 'T', 9: '9', 8: '8',
                           7: '7', 6: '6', 5: '5', 4: '4', 3: '3', 2: '2' };
        const highPairName = rankNames2[highPair] || highPair;
        const lowPairName = rankNames2[lowPair] || lowPair;
        return `Two Pair (${highPairName}s and ${lowPairName}s)`;
      }

      case 'One Pair': {
        const pairRank = Object.keys(rankCounts).find(
          rank => rankCounts[rank] === 2);
        return `One Pair (${pairRank}s)`;
      }

      case 'High Card':
        return `High Card (${cards[0].rank} high)`;

      default:
        return handRank.name;
    }
  }

  /**
   * Compare two hand evaluation results
   * @param {Object} hand1 - First hand evaluation
   * @param {Object} hand2 - Second hand evaluation
   * @returns {number} Positive if hand1 > hand2, 0 if equal, negative if hand1 < hand2
   */
  static compareHands(hand1, hand2) {
    if (hand1.handRank !== hand2.handRank) {
      return hand1.handRank - hand2.handRank; // Positive = hand1 wins
    }

    return hand1.handValue - hand2.handValue; // Positive = hand1 wins
  }
}

// Hand rankings (higher is better)
HandEvaluator.HAND_RANKS = {
  'High Card': 1,
  'One Pair': 2,
  'Two Pair': 3,
  'Three of a Kind': 4,
  'Straight': 5,
  'Flush': 6,
  'Full House': 7,
  'Four of a Kind': 8,
  'Straight Flush': 9,
  'Royal Flush': 10
};

module.exports = HandEvaluator;