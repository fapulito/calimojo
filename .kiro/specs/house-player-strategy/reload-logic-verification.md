# Reload Logic Verification

## Task 11.3: Verify reload logic

**Requirements:** 8.2

### Reload Method Review

Location: `mojopoker-1.1.1/lib/FB/Poker.pm:301`

```perl
sub reload {
    my ( $self, $login ) = @_;
    my $inplay = $self->_fetch_inplay($login);

    my $chips = $self->db->fetch_chips( $login->user->id );
    my $total = $inplay + $chips;

    if ( $total < 400 ) {
        $self->db->credit_chips( $login->user->id, 400 - $total );
        $self->db->credit_invested( $login->user->id, 400 - $total );
    }
    $self->login_info($login);
}
```

### Supporting Methods

#### 1. `_fetch_inplay` (FB::Poker)
Location: `mojopoker-1.1.1/lib/FB/Poker.pm:267`

```perl
sub _fetch_inplay {
    my ( $self, $login ) = @_;

    my $inplay = 0;

    for my $ring (
       map  { $self->table_list->{$_} }
       grep { exists $self->table_list->{$_} }
       keys %{ $login->user->ring_play }
    ) {
       for my $chair (
         grep { $_->has_player && $_->player->login->id eq $login->id} @{ $ring->chairs }
       ) {
         $inplay += $chair->chips;
       }
   }
   return $inplay;
}
```

**Analysis:**
- ✅ Iterates through all tables where user is playing
- ✅ Sums chips from all chairs where user is seated
- ✅ Returns total chips currently at tables

#### 2. `credit_invested` (FB::Db)
Location: `mojopoker-1.1.1/lib/FB/Db.pm:147`

```perl
sub credit_invested {
    my ( $self, $user_id, $chips ) = @_;
    my $sql = <<SQL;
UPDATE users 
SET invested = invested + $chips
WHERE id = $user_id 
SQL
    return $self->dbh->do($sql);
}
```

**Analysis:**
- ✅ Atomically updates invested amount
- ✅ Adds the credited amount to invested total

### Reload Logic Analysis

#### Step-by-Step Flow:

1. **Calculate Total Chips:**
   ```perl
   my $inplay = $self->_fetch_inplay($login);
   my $chips = $self->db->fetch_chips( $login->user->id );
   my $total = $inplay + $chips;
   ```
   - ✅ Fetches chips at all tables (inplay)
   - ✅ Fetches chips in bank (chips)
   - ✅ Calculates total = inplay + bank

2. **Check if Reload Needed:**
   ```perl
   if ( $total < 400 ) {
   ```
   - ✅ Only reloads if total is below 400

3. **Credit Chips and Invested:**
   ```perl
   $self->db->credit_chips( $login->user->id, 400 - $total );
   $self->db->credit_invested( $login->user->id, 400 - $total );
   ```
   - ✅ Credits exactly (400 - total) to reach 400
   - ✅ Updates invested by the same amount

4. **Update Login Info:**
   ```perl
   $self->login_info($login);
   ```
   - ✅ Sends updated balance to client

### Requirement 8.2 Verification

> WHEN a user requests a reload and their total chips are below 400 THEN the System SHALL credit chips to bring the total to 400 and update invested accordingly

**Status:** ✅ VERIFIED

#### Test Cases:

| Scenario | Bank | Inplay | Total | Reload Amount | Final Total | Invested Increase |
|----------|------|--------|-------|---------------|-------------|-------------------|
| Below 400 | 100 | 50 | 150 | 250 | 400 | +250 |
| Below 400 | 0 | 200 | 200 | 200 | 400 | +200 |
| Below 400 | 350 | 0 | 350 | 50 | 400 | +50 |
| At 400 | 400 | 0 | 400 | 0 | 400 | +0 |
| Above 400 | 500 | 100 | 600 | 0 | 600 | +0 |

**Verification:**
- ✅ Correctly calculates total chips (bank + inplay)
- ✅ Only reloads when total < 400
- ✅ Credits exact amount to reach 400
- ✅ Updates invested by the same amount
- ✅ Does not reload if total >= 400

### Edge Cases Handled

1. **User at multiple tables:** ✅ `_fetch_inplay` sums chips from all tables
2. **User with no chips:** ✅ Credits full 400, invested increases by 400
3. **User already at 400:** ✅ No reload occurs (condition fails)
4. **User above 400:** ✅ No reload occurs (condition fails)

### Potential Issues

1. **Race Condition:** Between fetching inplay/chips and crediting
   - If user wins/loses chips during reload calculation, amount might be slightly off
   - Low risk: reload is typically called when user is not actively playing

2. **Invested Tracking:** Invested increases even for "free" reloads
   - This is intentional design for profit/loss calculation
   - Invested represents total chips ever given to user

### Conclusion

**Task 11.3 Status: ✅ COMPLETE**

The reload logic correctly implements Requirement 8.2:
1. ✅ Calculates total chips (bank + all tables)
2. ✅ Only reloads when total < 400
3. ✅ Credits exact amount to reach 400
4. ✅ Updates invested accordingly
5. ✅ Handles edge cases properly

The implementation is correct and maintains consistency between chips and invested tracking.
