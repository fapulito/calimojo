#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

# Test Strategy Manager integration
# Requirements: 1.1, 2.4, 4.1, 4.2

use_ok('FB::Poker::Strategy::Manager');
use_ok('FB::Poker::Strategy::Evaluator::Holdem');
use_ok('FB::Poker::Strategy::Evaluator::Omaha');
use_ok('FB::Poker::Strategy::Evaluator::Draw');
use_ok('FB::Poker::Strategy::Config');
use_ok('FB::Poker::Card');

# Test 1: Manager creation
my $manager = FB::Poker::Strategy::Manager->new;
isa_ok($manager, 'FB::Poker::Strategy::Manager', 'Manager created');
isa_ok($manager->config, 'FB::Poker::Strategy::Config', 'Config initialized');

# Test 2: Evaluator registration (Requirement 2.4)
my $holdem_eval = FB::Poker::Strategy::Evaluator::Holdem->new;
ok($manager->register_evaluator('holdem', $holdem_eval), 'Registered holdem evaluator');

my $omaha_eval = FB::Poker::Strategy::Evaluator::Omaha->new;
ok($manager->register_evaluator('omaha', $omaha_eval), 'Registered omaha evaluator');

my $draw_eval = FB::Poker::Strategy::Evaluator::Draw->new;
ok($manager->register_evaluator('draw', $draw_eval), 'Registered draw evaluator');

# Test 3: Evaluator retrieval
my $retrieved = $manager->get_evaluator('holdem');
is($retrieved, $holdem_eval, 'Retrieved correct evaluator for holdem');

$retrieved = $manager->get_evaluator('omaha');
is($retrieved, $omaha_eval, 'Retrieved correct evaluator for omaha');

$retrieved = $manager->get_evaluator('nonexistent');
is($retrieved, undef, 'Returns undef for unregistered game class');

# Test 4: Default action when no table/chair provided
my $decision = $manager->decide_action(undef, undef);
is($decision->{action}, 'check', 'Returns default check action when no table');
is($decision->{amount}, 0, 'Default action has zero amount');

done_testing();
