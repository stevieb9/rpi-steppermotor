use strict;
use warnings;

use RPi::StepperMotor;
use RPi::Const qw(:all);
use Test::More;

# HW-free coverage. new() makes exactly one WiringPi call (setup_gpio); stub it
# so no GPIO is touched. Everything else is driven through an injected mock
# expander, whose write()/mode() calls we capture - so the step patterns, the
# step-counter wrap and the validation all run with no motor and no Pi.
{
    no warnings 'redefine';
    *RPi::StepperMotor::setup_gpio = sub { };
}

{
    package Mock::Expander;
    sub new   { bless { writes => [], modes => [] }, shift }
    sub mode  { push @{ $_[0]{modes} },  [$_[1], $_[2]] }
    sub write { push @{ $_[0]{writes} }, [$_[1], $_[2]] }
}

my $mod = 'RPi::StepperMotor';

# The driver sequence, duplicated here so the test is an independent check of
# what cw()/ccw() actually put on the pins.
my @SEQ = (
    [1, 0, 0, 1], [1, 0, 0, 0], [1, 1, 0, 0], [0, 1, 0, 0],
    [0, 1, 1, 0], [0, 0, 1, 0], [0, 0, 1, 1], [0, 0, 0, 1],
);

sub motor {
    my (%extra) = @_;
    return $mod->new(
        pins     => [0, 1, 2, 3],
        expander => Mock::Expander->new,
        delay    => 0,
        %extra,
    );
}

# --- construction + pin validation croaks ---
eval { $mod->new(expander => Mock::Expander->new) };
like $@, qr/'pins' parameter is required/, 'new(): missing pins croaks';

eval { $mod->new(pins => [1, 2, 3], expander => Mock::Expander->new) };
like $@, qr/four elements/, 'new(): pins aref must have exactly four elements';

# --- speed() validation (F10: this used to be dead code that never croaked) ---
{
    my $sm = motor();
    is $sm->speed, 'half', 'speed(): defaults to half';
    is $sm->speed('full'), 'full', "speed('full'): accepted";
    is $sm->speed('half'), 'half', "speed('half'): accepted";

    eval { $sm->speed('turbo') };
    like $@, qr/must be either 'full' or 'half'/, "speed('turbo'): croaks (F10 fix)";
}

# --- _turns(): 64:1 gearing with round-half-up on the phase divisor ---
{
    my $sm = motor(speed => 'half');
    is $sm->_turns(180), 2048, '_turns(180) half = int(32.5)*64';
    is $sm->_turns(5.625), 64, '_turns(5.625) half rounds to one phase-unit *64';
    is $sm->_turns(1), 0, '_turns(1) half rounds down to zero';

    $sm->speed('full');
    is $sm->_turns(180), 1024, '_turns(180) full = int(16.5)*64';
}

# --- cw()/ccw() step patterns + counter wrap (captured via the mock) ---
{
    my $sm = motor;   # half speed

    # Pin order + HIGH/LOW mapping of the very first step (sequence index 0)
    my @first = @{ steps_raw($sm, 'cw', 6) }[0 .. 3];
    is_deeply [map { $_->[0] } @first], [0, 1, 2, 3],
        'cw(): drives the four pins in IN1..IN4 order';
    is_deeply [map { $_->[1] } @first], [HIGH, LOW, LOW, HIGH],
        'cw(): step 0 sets the pins per sequence [1,0,0,1]';

    is_deeply [ (step_indices($sm, 'cw',  6))[0 .. 8] ], [0, 1, 2, 3, 4, 5, 6, 7, 0],
        'cw half: step index advances by one and wraps at 8';

    is_deeply [ (step_indices($sm, 'ccw', 6))[0 .. 8] ], [0, 7, 6, 5, 4, 3, 2, 1, 0],
        'ccw half: step index decrements and wraps at 0';

    $sm->speed('full');
    is_deeply [ (step_indices($sm, 'cw', 12))[0 .. 7] ], [0, 2, 4, 6, 0, 2, 4, 6],
        'cw full: step index advances by two (skips every other step)';
}

# --- direction validation ---
{
    my $sm = motor;
    eval { $sm->cw() };
    like $@, qr/degrees must be specified/, 'cw(): missing degrees croaks';
}

# --- off(): de-energizes all four coil pins, pins stay OUTPUT ---
{
    my $sm = motor;

    $sm->cw(6);                            # Energize the coils through a move

    @{ $sm->_expander->{writes} } = ();    # Isolate just off()'s writes/modes
    @{ $sm->_expander->{modes} }  = ();

    is $sm->off, 0, 'off(): returns 0';

    is_deeply
        [sort { $a->[0] <=> $b->[0] } @{ $sm->_expander->{writes} }],
        [[0, LOW], [1, LOW], [2, LOW], [3, LOW]],
        'off(): drives all four coil pins LOW';

    is_deeply $sm->_expander->{modes}, [],
        'off(): makes no mode() changes, so the pins stay OUTPUT';
}

# --- cleanup() de-energizes the expander path too (it used to do nothing) ---
{
    my $sm = motor;

    $sm->cw(6);

    @{ $sm->_expander->{writes} } = ();

    $sm->cleanup;

    is_deeply
        [sort { $a->[0] <=> $b->[0] } @{ $sm->_expander->{writes} }],
        [[0, LOW], [1, LOW], [2, LOW], [3, LOW]],
        'cleanup(): de-energizes an expander-driven motor via off()';
}

done_testing();

# Run one move and return the raw [pin, value] writes it emitted.
sub steps_raw {
    my ($sm, $dir, $degrees) = @_;
    @{ $sm->_expander->{writes} } = ();
    $sm->$dir($degrees);
    return $sm->_expander->{writes};
}

# Run one move and return the sequence of STEPPER_SEQUENCE indices it stepped
# through (each step is four consecutive pin writes).
sub step_indices {
    my ($sm, $dir, $degrees) = @_;

    my @w = @{ steps_raw($sm, $dir, $degrees) };
    my @indices;

    for (my $i = 0; $i + 3 < @w; $i += 4){
        my @pat = map { $w[$i + $_][1] ? 1 : 0 } 0 .. 3;
        my ($idx) = grep { "@{ $SEQ[$_] }" eq "@pat" } 0 .. $#SEQ;
        push @indices, $idx;
    }

    return @indices;
}
