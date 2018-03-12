use warnings;
use strict;

use RPi::Const qw(:all);
use WiringPi::API qw(:perl);

# catch sig int so we can clean up the pins later

my $continue = 1;

$SIG{INT} = sub {
    print "\n\ncleaning up pins and exiting...\n";
    $continue = 0;
};

# how much travel (in degrees 0-360)

if (! defined $ARGV[0]){
    die "need to specify degrees to turn the damned motor!\n";
}

my $deg = $ARGV[0];

# half-step (half speed) == 1, full-step (full speed) == 2
# valid values, -2, -1 (counter-clockwise) and 1, 2 (clockwise)

my $step_speed = 1;
$step_speed = $ARGV[1] if defined $ARGV[1];

print "STEP DIR: $step_speed\n";

setup_gpio();

# gpio pins IN1, IN2, IN3, IN4

my @stepper_pins = qw(12 16 20 21);

for (@stepper_pins){
    pin_mode($_, OUTPUT);
    write_pin($_, LOW);
}

# the full 8-step sequence

my $seq = [
    [qw(1 0 0 1)],
    [qw(1 0 0 0)],
    [qw(1 1 0 0)],
    [qw(0 1 0 0)],
    [qw(0 1 1 0)],
    [qw(0 0 1 0)],
    [qw(0 0 1 1)],
    [qw(0 0 0 1)],
];

my $step_count = @$seq;
my $wait_time = 0.01;

my $turns = $step_speed =~ /1$/
    ? int($deg / 5.625 + 0.5) * 64
    : int($deg / 11.25 + 0.5) * 64;

print "TURNS: $turns\n";

my $step_counter = 0;

for (1..$turns) {
    for my $gpio_pin (0 .. 3) {
        # print "counter: $step_counter\n";
        for ($seq->[$step_counter][$gpio_pin]) {
            # print "seq: $_\n";
        }
        if ($seq->[$step_counter][$gpio_pin]) {
            print "turning pin $stepper_pins[$gpio_pin] HIGH\n";
            write_pin($stepper_pins[$gpio_pin], HIGH);
        }
        else {
            print "turning pin $stepper_pins[$gpio_pin] LOW\n";
            write_pin($stepper_pins[$gpio_pin], LOW);
        }
    }

    $step_counter += $step_speed;

#    print "STEP COUNTER: $step_counter\n";

    if ($step_counter >= $step_count) {
        $step_counter = 0;
    }
    if ($step_counter < 0) {
        $step_counter = $step_count + $step_speed;
    }

    select(undef, undef, undef, $wait_time);
}

for (@stepper_pins){
    write_pin($_, LOW);
    pin_mode($_, OUTPUT);
}

