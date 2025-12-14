const HandEvaluator = require('./lib/poker/HandEvaluator');
const Card = require('./lib/poker/Card');
const Deck = require('./lib/poker/Deck');

console.log('🧪 Testing Hand Evaluator...');

async function testHandEvaluator() {
  try {
    // Test 1: Royal Flush
    console.log('\\n1. Testing Royal Flush...');
    const royalFlushCards = [
      new Card('hearts', '10', '10h'),
      new Card('hearts', 'J', 'Jh'),
      new Card('hearts', 'Q', 'Qh'),
      new Card('hearts', 'K', 'Kh'),
      new Card('hearts', 'A', 'Ah')
    ];

    const royalFlushResult = HandEvaluator.evaluateHand(royalFlushCards);
    console.log('Result:', royalFlushResult.description);
    console.log('Hand Rank:', royalFlushResult.handRank, '(should be 10)');
    console.log('✅ Royal Flush test:', royalFlushResult.handName === 'Royal Flush');

    // Test 2: Straight Flush
    console.log('\\n2. Testing Straight Flush...');
    const straightFlushCards = [
      new Card('spades', '5', '5s'),
      new Card('spades', '6', '6s'),
      new Card('spades', '7', '7s'),
      new Card('spades', '8', '8s'),
      new Card('spades', '9', '9s')
    ];

    const straightFlushResult = HandEvaluator.evaluateHand(straightFlushCards);
    console.log('Result:', straightFlushResult.description);
    console.log('Hand Rank:', straightFlushResult.handRank, '(should be 9)');
    console.log('✅ Straight Flush test:', straightFlushResult.handName === 'Straight Flush');

    // Test 3: Four of a Kind
    console.log('\\n3. Testing Four of a Kind...');
    const fourOfAKindCards = [
      new Card('hearts', 'Q', 'Qh'),
      new Card('diamonds', 'Q', 'Qd'),
      new Card('clubs', 'Q', 'Qc'),
      new Card('spades', 'Q', 'Qs'),
      new Card('hearts', 'K', 'Kh')
    ];

    const fourOfAKindResult = HandEvaluator.evaluateHand(fourOfAKindCards);
    console.log('Result:', fourOfAKindResult.description);
    console.log('Hand Rank:', fourOfAKindResult.handRank, '(should be 8)');
    console.log('✅ Four of a Kind test:', fourOfAKindResult.handName === 'Four of a Kind');

    // Test 4: Full House
    console.log('\\n4. Testing Full House...');
    const fullHouseCards = [
      new Card('hearts', 'J', 'Jh'),
      new Card('diamonds', 'J', 'Jd'),
      new Card('clubs', 'J', 'Jc'),
      new Card('spades', '5', '5s'),
      new Card('hearts', '5', '5h')
    ];

    const fullHouseResult = HandEvaluator.evaluateHand(fullHouseCards);
    console.log('Result:', fullHouseResult.description);
    console.log('Hand Rank:', fullHouseResult.handRank, '(should be 7)');
    console.log('✅ Full House test:', fullHouseResult.handName === 'Full House');

    // Test 5: Flush
    console.log('\\n5. Testing Flush...');
    const flushCards = [
      new Card('clubs', '2', '2c'),
      new Card('clubs', '5', '5c'),
      new Card('clubs', '7', '7c'),
      new Card('clubs', 'J', 'Jc'),
      new Card('clubs', 'A', 'Ac')
    ];

    const flushResult = HandEvaluator.evaluateHand(flushCards);
    console.log('Result:', flushResult.description);
    console.log('Hand Rank:', flushResult.handRank, '(should be 6)');
    console.log('✅ Flush test:', flushResult.handName === 'Flush');

    // Test 6: Straight
    console.log('\\n6. Testing Straight...');
    const straightCards = [
      new Card('hearts', '3', '3h'),
      new Card('diamonds', '4', '4d'),
      new Card('clubs', '5', '5c'),
      new Card('spades', '6', '6s'),
      new Card('hearts', '7', '7h')
    ];

    const straightResult = HandEvaluator.evaluateHand(straightCards);
    console.log('Result:', straightResult.description);
    console.log('Hand Rank:', straightResult.handRank, '(should be 5)');
    console.log('✅ Straight test:', straightResult.handName === 'Straight');

    // Test 7: Three of a Kind
    console.log('\\n7. Testing Three of a Kind...');
    const threeOfAKindCards = [
      new Card('hearts', '8', '8h'),
      new Card('diamonds', '8', '8d'),
      new Card('clubs', '8', '8c'),
      new Card('spades', '2', '2s'),
      new Card('hearts', 'K', 'Kh')
    ];

    const threeOfAKindResult = HandEvaluator.evaluateHand(threeOfAKindCards);
    console.log('Result:', threeOfAKindResult.description);
    console.log('Hand Rank:', threeOfAKindResult.handRank, '(should be 4)');
    console.log('✅ Three of a Kind test:', threeOfAKindResult.handName === 'Three of a Kind');

    // Test 8: Two Pair
    console.log('\\n8. Testing Two Pair...');
    const twoPairCards = [
      new Card('hearts', 'A', 'Ah'),
      new Card('diamonds', 'A', 'Ad'),
      new Card('clubs', 'K', 'Kc'),
      new Card('spades', 'K', 'Ks'),
      new Card('hearts', 'Q', 'Qh')
    ];

    const twoPairResult = HandEvaluator.evaluateHand(twoPairCards);
    console.log('Result:', twoPairResult.description);
    console.log('Hand Rank:', twoPairResult.handRank, '(should be 3)');
    console.log('✅ Two Pair test:', twoPairResult.handName === 'Two Pair');

    // Test 9: One Pair
    console.log('\\n9. Testing One Pair...');
    const onePairCards = [
      new Card('hearts', '9', '9h'),
      new Card('diamonds', '9', '9d'),
      new Card('clubs', '2', '2c'),
      new Card('spades', '5', '5s'),
      new Card('hearts', 'J', 'Jh')
    ];

    const onePairResult = HandEvaluator.evaluateHand(onePairCards);
    console.log('Result:', onePairResult.description);
    console.log('Hand Rank:', onePairResult.handRank, '(should be 2)');
    console.log('✅ One Pair test:', onePairResult.handName === 'One Pair');

    // Test 10: High Card
    console.log('\\n10. Testing High Card...');
    const highCardCards = [
      new Card('hearts', '2', '2h'),
      new Card('diamonds', '4', '4d'),
      new Card('clubs', '6', '6c'),
      new Card('spades', '8', '8s'),
      new Card('hearts', 'T', 'Th')
    ];

    const highCardResult = HandEvaluator.evaluateHand(highCardCards);
    console.log('Result:', highCardResult.description);
    console.log('Hand Rank:', highCardResult.handRank, '(should be 1)');
    console.log('✅ High Card test:', highCardResult.handName === 'High Card');

    // Test 11: Hand Comparison
    console.log('\\n11. Testing Hand Comparison...');
    const hand1 = HandEvaluator.evaluateHand(onePairCards);
    const hand2 = HandEvaluator.evaluateHand(highCardCards);
    const comparison = HandEvaluator.compareHands(hand1, hand2);
    console.log('One Pair vs High Card:', comparison > 0 ? 'One Pair wins ✅' : 'Comparison failed ❌');

    // Test 12: Deck and Hand Integration
    console.log('\\n12. Testing Deck Integration...');
    const deck = Deck.createStandard();
    const dealtCards = deck.dealMultiple(5);
    const handResult = HandEvaluator.evaluateHand(dealtCards);
    console.log('Dealt hand:', dealtCards.map(c => c.toString()).join(', '));
    console.log('Hand evaluation:', handResult.description);
    console.log('✅ Deck integration test: Hand evaluated successfully');

    console.log('\\n🎉 All hand evaluator tests completed!');

  } catch (error) {
    console.error('❌ Hand evaluator test failed:', error.message);
    console.error(error.stack);
  }
}

testHandEvaluator();