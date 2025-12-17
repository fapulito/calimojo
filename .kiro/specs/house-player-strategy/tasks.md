# Implementation Plan

- [x] 1. Set up Strategy Module structure and core interfaces





  - [x] 1.1 Create directory structure for strategy module


    - Create `lib/FB/Poker/Strategy/` directory
    - Create placeholder files for Manager.pm, Config.pm, ActionDecider.pm
    - Create `lib/FB/Poker/Strategy/Evaluator/` directory for game-specific evaluators
    - _Requirements: 1.1, 2.4_

  - [x] 1.2 Implement Strategy::Config with validation


    - Create Config.pm with aggression, tightness, bluff_frequency, randomization_factor attributes
    - Implement validation for all parameters (1-10 range for aggression/tightness, 0.05-0.15 for bluff)
    - Implement validate() method that returns boolean
    - _Requirements: 5.1, 5.2, 5.4_

  - [ ]* 1.3 Write property test for configuration validation
    - **Property 10: Configuration Validation**
    - **Validates: Requirements 5.4**


- [x] 2. Implement Hand Evaluator framework




  - [x] 2.1 Create HandEvaluator role with required methods


    - Create `lib/FB/Poker/Strategy/HandEvaluator.pm` as Moo::Role
    - Define required methods: evaluate_hand, evaluate_potential, select_discards
    - Implement normalize_score helper method
    - _Requirements: 1.2_

  - [x] 2.2 Implement Texas Hold'em evaluator


    - Create `lib/FB/Poker/Strategy/Evaluator/Holdem.pm`
    - Integrate with existing FB::Poker::Eval for 7-card evaluation
    - Return normalized strength score 0.0-1.0
    - _Requirements: 2.1_

  - [ ]* 2.3 Write property test for hand strength normalization
    - **Property 1: Hand Strength Normalization**
    - **Validates: Requirements 1.2**

  - [x] 2.4 Implement Omaha evaluator


    - Create `lib/FB/Poker/Strategy/Evaluator/Omaha.pm`
    - Implement 2+3 card selection rule (exactly 2 hole cards + 3 community)
    - Evaluate all valid combinations and return best hand strength
    - _Requirements: 2.2_

  - [ ]* 2.5 Write property test for Omaha hand composition
    - **Property 5: Omaha Hand Composition**
    - **Validates: Requirements 2.2**

  - [x] 2.6 Implement Draw poker evaluator


    - Create `lib/FB/Poker/Strategy/Evaluator/Draw.pm`
    - Implement select_discards method based on hand improvement potential
    - Return valid card indices for discard
    - _Requirements: 2.3_

  - [ ]* 2.7 Write property test for draw discard validity
    - **Property 6: Draw Discard Validity**
    - **Validates: Requirements 2.3**

- [x] 3. Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement Action Decider




  - [x] 4.1 Create ActionDecider with decision logic


    - Create `lib/FB/Poker/Strategy/ActionDecider.pm`
    - Implement decide() method that takes hand_strength and game_state
    - Implement calculate_bet_amount() with min/max bounds checking
    - Implement should_bluff() with configurable probability
    - _Requirements: 1.3, 1.4, 3.3_

  - [ ]* 4.2 Write property test for action validity
    - **Property 2: Action Validity**
    - **Validates: Requirements 1.3, 4.1, 4.2**

  - [ ]* 4.3 Write property test for bet amount bounds
    - **Property 3: Bet Amount Bounds**
    - **Validates: Requirements 1.4**

  - [x] 4.4 Implement randomization and variation

    - Add RNG with configurable seed per house player
    - Implement ±15% threshold variation
    - Implement slow-play logic for strong hands
    - _Requirements: 3.1, 3.2, 3.4_

  - [ ]* 4.5 Write property test for randomization variance
    - **Property 7: Randomization Variance**
    - **Validates: Requirements 3.1**

  - [ ]* 4.6 Write property test for bluff rate bounds
    - **Property 8: Bluff Rate Bounds**
    - **Validates: Requirements 3.3**

  - [ ]* 4.7 Write property test for independent RNG
    - **Property 9: Independent RNG**
    - **Validates: Requirements 3.4**



- [x] 5. Implement Strategy Manager


  - [x] 5.1 Create Strategy::Manager as central coordinator


    - Create `lib/FB/Poker/Strategy/Manager.pm`
    - Implement evaluator registry (game_class => evaluator mapping)
    - Implement decide_action() entry point
    - Implement register_evaluator() method
    - _Requirements: 1.1, 2.4_

  - [ ]* 5.2 Write property test for evaluator selection
    - **Property 4: Game Variant Evaluator Selection**
    - **Validates: Requirements 2.4**

  - [x] 5.3 Integrate Strategy Manager with game engine


    - Add strategy manager instance to FB.pm
    - Hook into table action cycle for house player turns
    - Ensure actions go through existing validation
    - _Requirements: 4.1, 4.2_


- [x] 6. Checkpoint - Ensure all tests pass




  - Ensure all tests pass, ask the user if questions arise.


- [x] 7. Implement house player auto-play




  - [x] 7.1 Add auto-play trigger for house players

    - Modify FB::Poker::Table to detect house player turns
    - Call Strategy Manager when house player action is required
    - Submit action through existing bet/check/fold/draw commands
    - _Requirements: 4.1, 4.2_

  - [x] 7.2 Implement automatic blind/ante posting


    - Detect when house player must post blinds or antes
    - Automatically deduct from chip stack
    - _Requirements: 4.3_

  - [x] 7.3 Implement automatic rebuy logic


    - Check chip stack against table minimum after each hand
    - Trigger rebuy from house player account if below minimum
    - _Requirements: 4.4_


- [x] 8. Verify Facebook authentication flow



  - [x] 8.1 Review and document existing Facebook auth implementation


    - Verify HMAC-SHA256 signature verification in authorize()
    - Document the signed request parsing flow
    - _Requirements: 6.1_

  - [ ]* 8.2 Write property test for signature verification
    - **Property 11: Facebook Signature Verification**
    - **Validates: Requirements 6.1**

  - [x] 8.3 Verify new user creation flow


    - Confirm new users get facebook_id stored
    - Confirm 400 chips and 400 invested on creation
    - Confirm bookmark generation with HMAC-SHA1
    - _Requirements: 6.2, 6.3, 6.4_

  - [ ]* 8.4 Write property test for new user initial state
    - **Property 12: New User Initial State**
    - **Validates: Requirements 6.2, 6.3, 6.4**

- [x] 9. Verify user persistence





  - [x] 9.1 Verify returning user retrieval


    - Confirm fetch_user returns existing user by facebook_id
    - Confirm chip balance is preserved
    - _Requirements: 7.1, 7.2_

  - [ ]* 9.2 Write property test for user retrieval idempotence
    - **Property 13: User Retrieval Idempotence**
    - **Validates: Requirements 7.1, 7.2**

  - [x] 9.3 Verify logout persistence

    - Confirm update_user saves chips and last_visit on logout
    - Confirm _cleanup calls update_user
    - _Requirements: 7.3_

  - [x] 9.4 Verify game reconnection

    - Confirm watch_table restores seat for reconnecting users
    - Confirm chip stack at table is preserved
    - _Requirements: 7.4_

- [ ] 10. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Verify chip management
  - [ ] 11.1 Verify chip balance consistency
    - Review credit_chips, debit_chips, table_chips operations
    - Confirm atomic updates maintain consistency
    - _Requirements: 8.1, 8.3_

  - [ ]* 11.2 Write property test for chip balance consistency
    - **Property 14: Chip Balance Consistency**
    - **Validates: Requirements 8.1, 8.3**

  - [ ] 11.3 Verify reload logic
    - Review reload() method in FB::Poker
    - Confirm chips credited to reach 400 when below
    - Confirm invested updated accordingly
    - _Requirements: 8.2_

  - [ ]* 11.4 Write property test for reload correctness
    - **Property 15: Reload Correctness**
    - **Validates: Requirements 8.2**

  - [ ] 11.5 Verify daily reset
    - Review reset_leaders() method
    - Confirm all users reset to 400 chips, 400 invested
    - _Requirements: 8.4_

- [ ] 12. Verify house player account management
  - [ ] 12.1 Verify house player naming convention
    - Review add_house_players.pl script
    - Confirm username pattern HousePlayer\d+
    - _Requirements: 9.1_

  - [ ]* 12.2 Write property test for naming convention
    - **Property 16: House Player Naming Convention**
    - **Validates: Requirements 9.1**

  - [ ] 12.3 Verify mock WebSocket usage
    - Review _add_house_players in FB.pm
    - Confirm FB::Login::WebSocket::Mock is used
    - Confirm send() does not transmit network data
    - _Requirements: 9.2, 9.3_

  - [ ]* 12.4 Write property test for mock WebSocket interface
    - **Property 17: Mock WebSocket Interface**
    - **Validates: Requirements 9.2, 9.3**

  - [ ] 12.5 Verify house player chip limits
    - Confirm house players can have 1000000 chips
    - Review add_house_players.pl chip allocation
    - _Requirements: 9.4_

- [ ] 13. Implement disconnection handling for mobile players
  - [ ] 13.1 Create Session Manager component
    - Create `lib/FB/Session/Manager.pm`
    - Implement disconnected_sessions hash to track disconnected players
    - Implement grace_timers hash for timeout management
    - Implement on_disconnect() to save session state and start timer
    - Implement on_reconnect() to restore session and cancel timer
    - Implement grace_expired() to clean up and fold player
    - _Requirements: 10.1, 10.2, 10.4_

  - [ ] 13.2 Add auto-action settings to Chair
    - Add auto_action attribute to FB::Poker::Chair (fold, check_fold, call_N)
    - Add auto_call_limit attribute for call_N mode
    - Add disconnected boolean flag
    - Implement apply_auto_action() method
    - _Requirements: 10.3, 11.1, 11.2, 11.3_

  - [ ]* 13.3 Write property test for auto-action correctness
    - **Property 19: Auto-Action Correctness**
    - **Validates: Requirements 10.3, 11.1, 11.2, 11.3**

  - [ ] 13.4 Integrate Session Manager with WebSocket handling
    - Hook on_disconnect into WebSocket close event in Ships::Websocket
    - Hook on_reconnect into connection establishment
    - Pass session manager reference to FB.pm
    - _Requirements: 10.1, 10.2_

  - [ ]* 13.5 Write property test for grace period session preservation
    - **Property 18: Grace Period Session Preservation**
    - **Validates: Requirements 10.1, 10.2**

  - [ ] 13.6 Integrate auto-action with table action cycle
    - Modify action_done() to check for disconnected player
    - Call apply_auto_action() when disconnected player's turn
    - Send notification of auto-action to player on reconnect
    - _Requirements: 10.3, 11.4_

  - [ ]* 13.7 Write property test for grace period expiration
    - **Property 20: Grace Period Expiration**
    - **Validates: Requirements 10.4**

  - [ ] 13.8 Add player commands for auto-action preferences
    - Add set_auto_action command to poker_command
    - Validate auto_action values (fold, check_fold, call_N)
    - Store preference in chair when seated
    - _Requirements: 11.1, 11.2, 11.3_

- [ ] 14. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
