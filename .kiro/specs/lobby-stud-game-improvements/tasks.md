# Implementation Plan

- [x] 1. Expand house player accounts





  - [x] 1.1 Update add_house_players.pl to create 7 house players


    - Modify the script to create HousePlayer1 through HousePlayer7
    - Each account gets 1000000 chips
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ]* 1.2 Write property test for house player naming convention
    - **Property 13: House Player Naming**
    - **Validates: Requirements 7.3**

  - [ ]* 1.3 Write property test for house player chip balance
    - **Property 12: House Player Chip Balance**
    - **Validates: Requirements 7.2**

- [ ] 2. Implement house player pool management
  - [ ] 2.1 Add house_player_pool and house_player_seated attributes to FB.pm
    - Add house_player_pool array to track all house player logins
    - Add house_player_seated hash to track which house players are at which tables
    - _Requirements: 7.4_

  - [ ] 2.2 Implement _init_house_players method
    - Create mock WebSocket connections for all 7 house players at startup
    - Add them to the house_player_pool
    - _Requirements: 7.1, 9.2_

  - [ ] 2.3 Implement _get_available_house_players method
    - Return house players not currently seated at any table
    - Accept count parameter to limit results
    - _Requirements: 7.4_

  - [ ]* 2.4 Write property test for house player uniqueness
    - **Property 14: House Player Uniqueness**
    - **Validates: Requirements 7.4**

- [ ] 3. Implement dynamic house player addition on join
  - [ ] 3.1 Implement _add_house_players_on_join method
    - Count current players at table
    - Calculate how many house players needed to reach 7
    - Get available house players from pool
    - Schedule additions with slight delays
    - _Requirements: 2.1, 2.2_

  - [ ] 3.2 Implement _get_distributed_chairs method
    - Find empty chairs at table
    - Distribute house players across chairs evenly
    - _Requirements: 2.3_

  - [ ] 3.3 Modify join_ring to trigger house player addition
    - Call _add_house_players_on_join after successful human join
    - _Requirements: 2.1_

  - [ ]* 3.4 Write property test for house player addition on join
    - **Property 2: House Player Addition on Join**
    - **Validates: Requirements 2.1**

  - [ ]* 3.5 Write property test for house player addition timing
    - **Property 3: House Player Addition Timing**
    - **Validates: Requirements 2.2**

  - [ ]* 3.6 Write property test for seat distribution
    - **Property 4: House Player Seat Distribution**
    - **Validates: Requirements 2.3**

- [ ] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement house player action timer
  - [ ] 5.1 Add house_action_timer attribute to Table.pm
    - Store timer reference for house player actions
    - _Requirements: 3.1, 3.2_

  - [ ] 5.2 Modify _house_player_action to use timer
    - Clear any existing timer
    - Set 0.5 second timer to execute action
    - Ensures action completes well before clock expires
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ] 5.3 Implement _execute_house_action with fallback
    - Get decision from strategy manager
    - If decision fails, default to check if legal, otherwise fold
    - Execute the action and call action_done
    - _Requirements: 3.4_

  - [ ]* 5.4 Write property test for action timing
    - **Property 5: House Player Action Timing**
    - **Validates: Requirements 3.1, 3.2**

  - [ ]* 5.5 Write property test for action fallback
    - **Property 6: House Player Action Fallback**
    - **Validates: Requirements 3.4**

- [ ] 6. Implement Stud hand evaluator
  - [ ] 6.1 Create FB::Poker::Strategy::Evaluator::Stud module
    - Implement evaluate_hand method for 7-card stud
    - Generate all 21 combinations of 5 from 7 cards
    - Return best hand strength normalized to 0.0-1.0
    - _Requirements: 5.1, 5.2_

  - [ ] 6.2 Register Stud evaluator in Strategy Manager
    - Add sevenstud, sevenstudhilo, sevenstudjokers, razz mappings
    - _Requirements: 5.1, 5.4_

  - [ ]* 6.3 Write property test for stud evaluator selection
    - **Property 9: Stud Evaluator Selection**
    - **Validates: Requirements 5.1**

  - [ ]* 6.4 Write property test for stud hand evaluation
    - **Property 10: Stud Hand Evaluation**
    - **Validates: Requirements 5.2**

- [ ] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Update strategy configuration for more aggressive play
  - [ ] 8.1 Update Strategy::Config defaults
    - Set aggression to 7 (from 5)
    - Set tightness to 4 (from 5)
    - Add call_threshold at 0.25
    - Add bet_raise_frequency at 0.40
    - _Requirements: 4.1, 4.2_

  - [ ] 8.2 Update ActionDecider to use new thresholds
    - Use call_threshold for medium hand decisions
    - Use bet_raise_frequency to increase betting
    - Reduce fold rate for medium-strength hands
    - _Requirements: 4.3, 4.4_

  - [ ]* 8.3 Write property test for bet/raise frequency
    - **Property 7: Bet/Raise Frequency**
    - **Validates: Requirements 4.3**

  - [ ]* 8.4 Write property test for medium hand call rate
    - **Property 8: Medium Hand Call Rate**
    - **Validates: Requirements 4.4**

- [ ] 9. Add 7-card stud table to demo games
  - [ ] 9.1 Update _create_test_tables to include sevenstud
    - Add sevenstud configuration with 8 chairs
    - Set pot-limit betting
    - Add ante and bring-in settings
    - _Requirements: 1.1, 1.2, 1.3_

  - [ ]* 9.2 Write property test for stud table chair count
    - **Property 1: Stud Table Chair Count**
    - **Validates: Requirements 1.2**

  - [ ]* 9.3 Write property test for demo game creation
    - **Property 11: Demo Game Creation**
    - **Validates: Requirements 6.2**

- [ ] 10. Update BUILD method to initialize house players
  - [ ] 10.1 Call _init_house_players in BUILD
    - Initialize house player pool before creating test tables
    - _Requirements: 7.1_

  - [ ] 10.2 Update _add_house_players to use pool
    - Use _get_available_house_players instead of fetching from DB
    - Track seated house players in house_player_seated
    - _Requirements: 7.4_

- [ ] 11. Add documentation for creating demo games
  - [ ] 11.1 Update README.md with demo game instructions
    - Document how to modify _create_test_tables
    - Document available game classes
    - Document mpadmin.pl usage
    - _Requirements: 6.1, 6.4_

- [ ] 12. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
