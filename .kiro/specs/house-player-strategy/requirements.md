# Requirements Document

## Introduction

This document specifies the requirements for a House Player Strategy Module that will control the automated actions of house players (bots) in the MojoPoker application. House players are automated accounts that participate in poker games to ensure tables always have active players, providing a better experience for human players. The module will implement intelligent decision-making for poker actions (bet, check, fold, draw) based on hand strength evaluation and game state analysis.

Additionally, this document clarifies how Facebook login integrates with the existing user account system for player persistence, account creation, and chip management.

## Glossary

- **House Player**: An automated player account (e.g., HousePlayer1, HousePlayer2) that participates in poker games without human control
- **Strategy Module**: A software component that evaluates game state and determines optimal poker actions for house players
- **Hand Strength**: A numerical evaluation of how strong a player's current cards are relative to possible hands
- **Game State**: The current status of a poker game including community cards, pot size, betting round, and player positions
- **Action**: A poker move such as bet, check, fold, call, or raise
- **Mock WebSocket**: A simulated WebSocket connection used by house players that doesn't transmit data over the network
- **Facebook Login**: OAuth-based authentication using Facebook's signed request mechanism to verify user identity
- **Signed Request**: A base64-encoded, HMAC-SHA256 signed payload from Facebook containing user authentication data
- **Bookmark**: A unique hash token (HMAC-SHA1) generated from user ID used for session persistence
- **Chips**: Virtual currency used for betting in poker games
- **Invested**: Total chips a player has received (used for profit/loss calculation)

## Requirements

### Requirement 1

**User Story:** As a system operator, I want house players to automatically make intelligent poker decisions, so that human players have engaging opponents at all times.

#### Acceptance Criteria

1. WHEN a house player's turn arrives THEN the Strategy_Module SHALL evaluate the current hand strength and return a valid action within 3 seconds
2. WHEN the Strategy_Module evaluates hand strength THEN the Strategy_Module SHALL calculate a numerical score between 0.0 and 1.0 based on card rankings and potential combinations
3. WHEN the Strategy_Module selects an action THEN the Strategy_Module SHALL choose from the set of legal actions available for the current game state
4. WHEN the Strategy_Module determines a bet amount THEN the Strategy_Module SHALL calculate an amount within the table's minimum and maximum bet limits

### Requirement 2

**User Story:** As a system operator, I want house players to use different strategies based on game type, so that they play appropriately for Texas Hold'em, Omaha, and other poker variants.

#### Acceptance Criteria

1. WHEN a house player joins a Texas Hold'em table THEN the Strategy_Module SHALL use hole cards and community cards to evaluate hand strength
2. WHEN a house player joins an Omaha table THEN the Strategy_Module SHALL use exactly two hole cards and three community cards for hand evaluation per Omaha rules
3. WHEN a house player joins a draw poker game THEN the Strategy_Module SHALL evaluate which cards to discard based on potential hand improvement
4. WHEN the game variant changes THEN the Strategy_Module SHALL load the appropriate evaluation rules for that variant

### Requirement 3

**User Story:** As a system operator, I want house players to vary their play style, so that they are not predictable and provide realistic opponents.

#### Acceptance Criteria

1. WHEN the Strategy_Module selects an action THEN the Strategy_Module SHALL incorporate a randomization factor of plus or minus 15 percent to the base decision threshold
2. WHEN a house player has a strong hand THEN the Strategy_Module SHALL occasionally check or make small bets to simulate slow-playing behavior
3. WHEN a house player has a weak hand THEN the Strategy_Module SHALL occasionally bluff with a probability between 5 and 15 percent based on pot odds
4. WHEN multiple house players are at the same table THEN each house player SHALL use independent random seeds for decision variation

### Requirement 4

**User Story:** As a system operator, I want house player actions to integrate seamlessly with the existing game engine, so that games proceed without errors or delays.

#### Acceptance Criteria

1. WHEN the game engine signals a house player's turn THEN the Strategy_Module SHALL respond using the same action interface as human players (bet, check, fold, draw commands)
2. WHEN the Strategy_Module returns an action THEN the action SHALL be processed through the existing table action validation logic
3. WHEN a house player needs to post blinds or antes THEN the Strategy_Module SHALL automatically post the required amount from the house player's chip stack
4. WHEN a house player's chip stack falls below the table minimum THEN the Strategy_Module SHALL trigger an automatic rebuy from the house player's account balance

### Requirement 5

**User Story:** As a system operator, I want to configure house player behavior parameters, so that I can tune the difficulty and play style of automated opponents.

#### Acceptance Criteria

1. WHEN the system administrator sets aggression level THEN the Strategy_Module SHALL adjust betting frequency and size according to the configured value between 1 and 10
2. WHEN the system administrator sets tightness level THEN the Strategy_Module SHALL adjust the hand strength threshold for entering pots according to the configured value between 1 and 10
3. WHEN configuration parameters are updated THEN the Strategy_Module SHALL apply new parameters to subsequent hands without requiring a server restart
4. WHEN invalid configuration values are provided THEN the Strategy_Module SHALL reject the configuration and maintain previous valid settings

### Requirement 6

**User Story:** As a new user, I want to create an account using Facebook login, so that I can start playing poker without a separate registration process.

#### Acceptance Criteria

1. WHEN a user authenticates via Facebook THEN the System SHALL verify the signed request using HMAC-SHA256 with the configured Facebook app secret
2. WHEN Facebook authentication succeeds for a new user THEN the System SHALL create a new user record with the Facebook ID as the unique identifier
3. WHEN a new user account is created via Facebook THEN the System SHALL credit the account with 400 starting chips and set invested to 400
4. WHEN a new user account is created THEN the System SHALL generate a unique bookmark hash using HMAC-SHA1 of the user ID for session persistence

### Requirement 7

**User Story:** As a returning user, I want my account to persist between sessions, so that I keep my chips and progress when I log back in.

#### Acceptance Criteria

1. WHEN a user with an existing Facebook ID authenticates THEN the System SHALL retrieve the existing user record from the database
2. WHEN a returning user logs in THEN the System SHALL restore the user's current chip balance from the database
3. WHEN a user logs out or disconnects THEN the System SHALL save the current chip balance and last visit timestamp to the database
4. WHEN a user reconnects to an active game THEN the System SHALL restore the user's seat position and chip stack at the table

### Requirement 8

**User Story:** As a player, I want my chip balance to be accurately maintained, so that I can trust the game's fairness.

#### Acceptance Criteria

1. WHEN chips are won or lost in a hand THEN the System SHALL update the user's chip balance in the database immediately after hand completion
2. WHEN a user requests a reload and their total chips are below 400 THEN the System SHALL credit chips to bring the total to 400 and update invested accordingly
3. WHEN chips are transferred between bank and table THEN the System SHALL maintain consistency between the user's bank balance and table stack
4. WHEN the daily reset occurs THEN the System SHALL reset all user chip balances to 400 and invested to 400

### Requirement 10

**User Story:** As a mobile player, I want my game session to persist through brief disconnections, so that I do not lose my seat or miss my turn due to network interruptions.

#### Acceptance Criteria

1. WHEN a player disconnects from a table THEN the System SHALL preserve the player's seat and chip stack for a configurable grace period (default 60 seconds)
2. WHEN a player reconnects within the grace period THEN the System SHALL restore the player to their original seat with their chip stack intact
3. WHEN a player's turn arrives during disconnection THEN the System SHALL use auto-action settings (check if possible, fold if bet required) until the player reconnects or grace period expires
4. WHEN the grace period expires without reconnection THEN the System SHALL fold the player's hand and mark the seat as standing up after the current hand
5. WHEN a player reconnects to an active hand THEN the System SHALL immediately restore action control to the player if it is still their turn

### Requirement 11

**User Story:** As a mobile player, I want to set auto-action preferences, so that the game can act on my behalf during brief disconnections.

#### Acceptance Criteria

1. WHEN a player sets auto-fold preference THEN the System SHALL automatically fold the player's hand when action is required during disconnection
2. WHEN a player sets auto-check-fold preference THEN the System SHALL check when possible and fold when a bet is required during disconnection
3. WHEN a player sets auto-call preference THEN the System SHALL call up to a configurable amount when action is required during disconnection
4. WHEN auto-action is taken THEN the System SHALL notify the player of the action taken upon reconnection

### Requirement 9

**User Story:** As a system operator, I want house player accounts to be managed separately from regular users, so that they can be easily identified and configured.

#### Acceptance Criteria

1. WHEN a house player account is created THEN the System SHALL store the account with a recognizable username pattern (HousePlayer followed by a number)
2. WHEN house players are initialized at server startup THEN the System SHALL create mock WebSocket connections that do not transmit network data
3. WHEN a house player joins a table THEN the System SHALL use the same join mechanism as human players but with the mock WebSocket interface
4. WHEN house player chip balances are set THEN the System SHALL allow balances significantly higher than regular player starting amounts (1000000 chips)

## Technical Notes

### Hand Strength Evaluation

The Strategy Module will need to implement hand evaluation for multiple poker variants:
- Texas Hold'em: 2 hole cards + 5 community cards, best 5-card hand
- Omaha: 4 hole cards + 5 community cards, must use exactly 2 hole cards and 3 community cards
- Draw games: 5 cards with discard/draw mechanics

### Integration Points

The Strategy Module integrates with:
- `FB::Poker::Table` - for game state and action submission
- `FB::Login::WebSocket::Mock` - for house player communication
- `FB::Db` - for chip management and persistence
- `FB::Poker::Eval` - for hand evaluation (existing module)

### Facebook Authentication Flow

1. Client obtains signed request from Facebook SDK
2. Server verifies signature using HMAC-SHA256 with app secret
3. Server extracts user_id from payload
4. Server creates or retrieves user record by facebook_id
5. Server generates bookmark for session persistence
6. Client can use bookmark for subsequent logins without re-authenticating
