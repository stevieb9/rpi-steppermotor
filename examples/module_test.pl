use warnings;
use strict;

use RPi::StepperMotor;

my $speed = $ARGV[2] // 'half';

my $s = RPi::StepperMotor->new(
    pins => [12, 16, 20, 21],
    speed => $speed
);

die "need degree arg!\n" if ! $ARGV[0];
die "need direction!\n" if ! $ARGV[1];


if ($ARGV[1] eq 'cw'){
    $s->cw($ARGV[0]);
}
else {
    $s->ccw($ARGV[0]);
}

$s->cleanup;
