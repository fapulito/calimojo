# Copyright (C) 2026, California Vision
# Meta Model API wrapper (Session 2). Single transport module for all model
# calls: API key from MODEL_API_KEY, fixture mode for offline work.
package FB::Fc::Model;
use strict;
use warnings;
use Moo;
use File::Basename qw(dirname);
use File::Spec;
use Mojo::JSON qw(j);
use Mojo::UserAgent;

# Canonical key var is MODEL_API_KEY (what .env holds); META_MODEL_API_KEY
# stays as a fallback alias.
has 'api_key' => (
    is      => 'ro',
    default => sub { $ENV{MODEL_API_KEY} // $ENV{META_MODEL_API_KEY} },
);

has 'api_base_url' => (
    is      => 'ro',
    default => sub { $ENV{MODEL_API_BASE_URL} // 'https://api.meta.ai/v1' },
);

has 'model' => (
    is      => 'ro',
    default => sub { $ENV{MODEL_API_MODEL} // 'muse-spark-1.3' },
);

has 'fixture' => (
    is      => 'ro',
    default => sub { ($ENV{FORECAST_FIXTURE} // '') eq '1' },
);

has 'fixture_dir' => (
    is      => 'ro',
    default => sub {
        my $mod = $INC{'FB/Fc/Model.pm'} or die 'FC:model: cannot locate module path';
        return File::Spec->catfile(dirname($mod), '..', '..', '..', 'fixtures');
    },
);

sub is_fixture { shift->fixture ? 1 : 0 }

# Default source snippets handed to the resolve operation when the caller
# supplies none (read from the fixtures dir, live or fixture mode alike).
sub default_snippets {
    my ($self) = @_;
    my $file = File::Spec->catfile($self->fixture_dir, 'fc_sources.json');
    open my $fh, '<', $file or die "FC:model: open $file: $!";
    local $/;
    my $data = eval { j(scalar <$fh>) };
    my $err = $@;
    close $fh;
    die "FC:model: bad fixture $file: $err" if $err;
    my $snips = ref $data eq 'HASH' ? $data->{snippets} : undef;
    die "FC:model: fixture fc_sources.json has no snippets"
        unless ref $snips eq 'ARRAY';
    return $snips;
}

my %OPS = (
    draft_questions => {
        fixture => 'fc_draft_questions.json',
        key     => 'drafts',
        want    => 'ARRAY',
    },
    resolve => {
        fixture => 'fc_resolve.json',
        key     => undef,
        want    => 'HASH',
    },
);

# generate('draft_questions', { headlines => [...], count => N })
# Returns the decoded payload (arrayref of draft hashes). Fixture mode
# returns the canned file; real mode POSTs a prompt and parses JSON out.
sub generate {
    my ($self, $operation, $input) = @_;
    my $op = $OPS{$operation} or die "FC:model: unknown operation $operation";
    return $self->_generate_fixture($op) if $self->is_fixture;
    return $self->_generate_real($operation, $op, $input // {});
}

sub _generate_fixture {
    my ($self, $op) = @_;
    my $file = File::Spec->catfile($self->fixture_dir, $op->{fixture});
    open my $fh, '<', $file or die "FC:model: open $file: $!";
    local $/;
    my $data = eval { j(scalar <$fh>) };
    close $fh;
    die "FC:model: bad fixture $file: $@" if $@;
    my $out = (ref $data eq 'HASH' && defined $op->{key}) ? $data->{ $op->{key} } : $data;
    die "FC:model: fixture $file: want $op->{want}" unless ref $out eq $op->{want};
    return $out;
}

sub _prompt_drafts {
    my ($input) = @_;
    my $headlines = $input->{headlines} // [];
    my $count = $input->{count} // scalar @$headlines;
    my $listed = join "\n", map { "- $_" } @$headlines;
    my $system = 'You draft forecasting questions. Reply with JSON only, no prose.';
    my $user = <<"PROMPT";
Draft $count yes/no forecasting questions, one per headline below. Each must
have explicit, checkable resolution criteria and an ISO resolution date
(YYYY-MM-DD). Reply ONLY with JSON of this shape:
{"drafts": [{"prompt": "...?", "resolution_criteria": "...", "resolution_date": "YYYY-MM-DD", "resolution_source": "...", "source_ref": "...", "settlement_rule": "..."}]}

Headlines:
$listed
PROMPT
    return ($system, $user);
}

sub _prompt_resolve {
    my ($input) = @_;
    my $snips = join "\n",
        map { '- ' . ($_->{source} // '?') . ': ' . ($_->{text} // '') }
        @{ $input->{snippets} // [] };
    my $system = 'You resolve forecasting questions. Reply with JSON only, no prose.';
    my $user = <<"PROMPT";
Resolve this yes/no question against its criteria using the sources below.
Reply ONLY with JSON of this shape:
{"outcome": "YES|NO", "reasoning": "...", "sources_used": [{"source": "...", "ref": "..."}]}

Question: $input->{prompt}
Criteria: $input->{criteria}

Sources:
$snips
PROMPT
    return ($system, $user);
}

sub _generate_real {
    my ($self, $operation, $op, $input) = @_;
    die 'FC:no_api_key: set MODEL_API_KEY' unless $self->api_key;
    my ($system, $user) = $operation eq 'draft_questions'
        ? _prompt_drafts($input)
        : $operation eq 'resolve'
        ? _prompt_resolve($input)
        : die "FC:model: no prompt for $operation";
    my $ua = Mojo::UserAgent->new(request_timeout => 30, inactivity_timeout => 30);
    (my $base = $self->api_base_url) =~ s{/+$}{};
    my $tx = $ua->post(
        "$base/chat/completions" => { Authorization => 'Bearer ' . $self->api_key } => json => {
            model    => $self->model,
            messages => [
                { role => 'system', content => $system },
                { role => 'user',   content => $user },
            ],
        });
    my $res = $tx->result;
    die 'FC:model_http: ' . ($tx->error->{message} // 'request failed')
        if $tx->error;
    die 'FC:model_http: status ' . $res->code unless $res->is_success;
    my $text = eval { $res->json->{choices}[0]{message}{content} } // '';
    my ($json) = $text =~ /(\{.*\})/s;
    die 'FC:model_parse: no JSON object in model reply' unless $json;
    my $data = eval { j($json) };
    die "FC:model_parse: $@" if $@;
    my $out = (ref $data eq 'HASH' && defined $op->{key}) ? $data->{ $op->{key} } : $data;
    die "FC:model_parse: reply want $op->{want}" unless ref $out eq $op->{want};
    return $out;
}

1;

__END__

=head1 NAME

FB::Fc::Model - Meta Model API wrapper with fixture mode (Session 2)

=head1 MODES

Real mode POSTs C</chat/completions> on an OpenAI-compatible base URL
(C<MODEL_API_BASE_URL>, default C<https://api.meta.ai/v1>) using model
(C<MODEL_API_MODEL>, default C<muse-spark-1.3>), authenticated with the
C<MODEL_API_KEY> bearer key (C<META_MODEL_API_KEY> works as an alias).
Live mode needs only the key set. Unset key fails closed with
C<FC:no_api_key> before any network call.

Fixture mode (C<FORECAST_FIXTURE=1>) skips the network entirely and returns
decoded local JSON fixtures, so generation, approval, and staking are fully
demoable and testable offline. Swapping in a real key is a config change.

=head1 METHODS

=over 4

=item generate($operation, $input)

Runs one named operation (C<draft_questions>, C<resolve>) and returns the
decoded payload. Dies C<FC:...> on transport, parse, or fixture errors.

=item default_snippets()

Source snippets from C<fc_sources.json> used when the caller gives none.

=back

=cut
