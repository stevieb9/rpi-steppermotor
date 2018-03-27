use strict;
use warnings;
use feature 'say';

use RPi::StepperMotor;
use Parallel::ForkManager;

my $pm = Parallel::ForkManager->new(4);

help() if ! $ARGV[0];
my $deg = $ARGV[0];
my $speed = $ARGV[1] // 'half';

my %motors = (
    s1 => { pins => [qw(4 17 27 22)] },
    s2 => { pins => [qw(5 6 13 19)] },
    s3 => { pins => [qw(18 23 24 25)] },
    s4 => { pins => [qw(12 16 20 21)] },
);

my $time = time;

say "starting: $time\n";

for my $motor_name (keys %motors) {

    my $motor = RPi::StepperMotor->new(
        pins => $motors{$motor_name}{pins},
        speed => $speed
    );
   
    my $direction = int(rand(2)) ? 'cw' : 'ccw';

    my $pid = $pm->start and next;

    say "$motor_name starting $direction";

    $direction eq 'cw' ? $motor->cw($deg) : $motor->ccw($deg);
    $motor->cleanup;

    say "$motor_name stopped";

    $pm->finish;
}

$pm->wait_all_children;

$time = time;
say "\nending: $time";

sub help {
    say "Usage: perl fork_four_motors.pl <degrees> [half|full]";
    exit;
}
