use strict;
use warnings;
use feature 'say';

use RPi::StepperMotor;
use Parallel::ForkManager;
 
my $pm = Parallel::ForkManager->new(4);
 
die "need degree arg!\n" if ! $ARGV[0];
if (! $ARGV[1] || $ARGV[1] !~ /cw/){
    die "need direction!\n";
}

my $speed = $ARGV[2] // 'half';

my $s1 = RPi::StepperMotor->new(
    pins => [qw(4 17 27 22)],
    speed => $speed,
    name => 's1'
);

my $s2 = RPi::StepperMotor->new(
    pins => [qw(5 6 13 19)],
    speed => $speed,
    name => 's2'
);

my $s3 = RPi::StepperMotor->new(
    pins => [qw(18 23 24 25)],
    speed => $speed,
    name => 's3'
);

my $s4 = RPi::StepperMotor->new(
    pins => [qw(12 16 20 21)],
    speed => $speed,
    name => 's4'
);

my @motors = ($s1, $s2, $s3, $s4);

for (@motors) {
    my $pid = $pm->start and next;
    say $_->name . " starting";
    $_->cw($ARGV[0]);
    $_->cleanup;
    say $_->name . " stopped";
    $pm->finish;
}
