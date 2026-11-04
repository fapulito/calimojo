# Requirements Document

## Introduction

This document specifies the requirements for improving the MojoPoker lobby experience by ensuring a 7-card stud game is always available, enhancing house player behavior to provide more engaging opponents, and documenting how to create additional demo games. The improvements address issues where house players allow the clock to expire when they have action first and fold too frequently.

## Glossary

- **Lobby**: The main interface where players browse and join available poker tables
- **7-Card Stud**: A poker variant where players receive 7 cards (3 down, 4 up) with no community cards
- **House Player**: An automated player account (e.g., HousePlayer1-HousePlayer7) that participates in poker games without human control
- **Action Timer**: The countdown clock that limits how long a player has to make a decision
- **Strategy Module**: The software component that evaluates game state and determines poker actions for house players
- **Demo Game**: A pre-configured poker table created at server startup for demonstration purposes
- **Stud Evaluator**: A hand evaluation component specific to 7-card stud poker variants

## Requirements

### Requirement 1

**User Story:** As a player, I want a 7-card stud game to always be available in the lobby, so that I can play my preferred poker variant at any time.

#### Acceptance Criteria

1. WHEN the server starts THEN the System SHALL create at least one 7-card stud table with pot-limit betting
2. WHEN a 7-card stud table is created THEN the System SHALL configure the table with 8 chairs to accommodate the maximum stud players
3. WHEN the lobby is displayed THEN the System SHALL show the 7-card stud table in the available games list
4. WHEN a player joins the 7-card stud table THEN the System SHALL apply stud-specific rules for dealing and betting rounds

### Requirement 2

**User Story:** As a player, I want house players to join my table when I sit down, so that I have opponents to play against immediately.

#### Acceptance Criteria

1. WHEN a human player sits at a table with fewer than 7 total players THEN the System SHALL add house players until 7 players are seated
2. WHEN house players are added to a table THEN the System SHALL add them within 5 seconds of the human player sitting
3. WHEN house players join a table THEN the System SHALL distribute them across available seats rather than clustering
4. WHEN a table already has 7 or more players THEN the System SHALL not add additional house players

### Requirement 3

**User Story:** As a player, I want house players to act promptly when it is their turn, so that the game flows smoothly without unnecessary delays.

#### Acceptance Criteria

1. WHEN a house player has action THEN the Strategy_Module SHALL execute the action within 2 seconds
2. WHEN a house player's turn begins THEN the System SHALL not allow the action timer to expire before making a decision
3. WHEN the Strategy_Module processes a house player turn THEN the System SHALL use a timer to ensure action completion
4. WHEN a house player action fails to execute THEN the System SHALL default to a valid action (check if possible, otherwise fold)

### Requirement 4

**User Story:** As a player, I want house players to play more aggressively and less predictably, so that games are more engaging and realistic.

#### Acceptance Criteria

1. WHEN the Strategy_Module evaluates a hand THEN the Strategy_Module SHALL use an aggression level of 7 (on a 1-10 scale) by default
2. WHEN the Strategy_Module evaluates a hand THEN the Strategy_Module SHALL use a tightness level of 4 (on a 1-10 scale) by default
3. WHEN a house player has a playable hand THEN the Strategy_Module SHALL bet or raise at least 40 percent of the time instead of just calling
4. WHEN a house player faces a bet THEN the Strategy_Module SHALL call with medium-strength hands rather than folding

### Requirement 5

**User Story:** As a player, I want house players to properly evaluate 7-card stud hands, so that they make appropriate decisions in stud games.

#### Acceptance Criteria

1. WHEN a house player is in a 7-card stud game THEN the Strategy_Module SHALL use a stud-specific hand evaluator
2. WHEN evaluating a stud hand THEN the Strategy_Module SHALL consider all 7 cards to find the best 5-card hand
3. WHEN evaluating a stud hand THEN the Strategy_Module SHALL account for visible opponent cards in decision making
4. WHEN the stud evaluator is not available THEN the Strategy_Module SHALL fall back to the default evaluator

### Requirement 6

**User Story:** As a system operator, I want to easily create additional demo games, so that I can customize the lobby for different player preferences.

#### Acceptance Criteria

1. WHEN the server starts THEN the System SHALL read demo game configurations from a designated location
2. WHEN a demo game configuration specifies a game class THEN the System SHALL create a table with that game variant
3. WHEN a demo game configuration specifies house player count THEN the System SHALL add that many house players to the table
4. WHEN documentation is requested THEN the System SHALL provide clear instructions for creating demo games

### Requirement 7

**User Story:** As a system operator, I want more house player accounts available, so that tables can have sufficient automated opponents.

#### Acceptance Criteria

1. WHEN the system initializes THEN the System SHALL ensure at least 7 house player accounts exist (HousePlayer1 through HousePlayer7)
2. WHEN a house player account is created THEN the System SHALL assign 1000000 chips to the account
3. WHEN house player accounts are created THEN the System SHALL follow the naming pattern HousePlayer followed by a number
4. WHEN house players are needed for a table THEN the System SHALL use accounts that are not already seated at other tables

## Technical Notes

### 7-Card Stud Game Class

The game class for 7-card stud is `sevenstud` as shown in the existing codebase. Related variants include:
- `sevenstud` - Standard 7-card stud
- `sevenstudhilo` - 7-card stud hi-lo split
- `sevenstudjokers` - 7-card stud with jokers wild

### Demo Game Configuration

Demo games can be configured in `mojopoker-1.1.1/db/example_games` or programmatically in `FB.pm`'s `_create_test_tables` method.

### House Player Action Timing

The current implementation may have timing issues where the action timer starts before the strategy module processes. A dedicated timer should ensure house player actions complete within the specified timeframe.
