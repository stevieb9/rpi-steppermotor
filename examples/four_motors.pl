use warnings;
use strict;

use RPi::StepperMotor;

die "need degree arg!\n" if ! $ARGV[0];
if (! $ARGV[1] || $ARGV[1] !~ /cw/){
    die "need direction!\n";
}

my $speed = $ARGV[2] // 'half';

my $s1 = RPi::StepperMotor->new(
    pins => [qw(4 17 27 22)],
    speed => $speed
);

my $s2 = RPi::StepperMotor->new(
    pins => [qw(5 6 13 19)],
    speed => $speed
);

my $s3 = RPi::StepperMotor->new(
    pins => [qw(18 23 24 25)],
    speed => $speed
);

my $s4 = RPi::StepperMotor->new(
    pins => [qw(12 16 20 21)],
    speed => $speed
);

my @motors = ($s1, $s2, $s3, $s4);

if ($ARGV[1] eq 'cw'){
    print "cw\n";
    for (@motors){
        $_->cw($ARGV[0]);
        $_->cleanup;
    }
}
else {
    print "ccw\n"; 
    for (@motors){
        $_->ccw($ARGV[0]);
        $_->cleanup;
    }
}


