package RPi::StepperMotor;

use 5.010;
use strict;
use warnings;

use Carp qw(croak);
use RPi::Const qw(:all);
use WiringPi::API qw(:perl);

our $VERSION = '2.3603';

use constant FULL => 2;
use constant HALF => 1;
use constant NUM_PINS => 0..3;

use constant STEPPER_SEQUENCE => [
    [qw(1 0 0 1)],
    [qw(1 0 0 0)],
    [qw(1 1 0 0)],
    [qw(0 1 0 0)],
    [qw(0 1 1 0)],
    [qw(0 0 1 0)],
    [qw(0 0 1 1)],
    [qw(0 0 0 1)],
];

use constant STEP_COUNT => 0+@{ STEPPER_SEQUENCE() };

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    if (! exists $args{pins}){
        croak "'pins' parameter is required to use this module\n";
    }

    setup_gpio();

    $self->_pins($args{pins});

    my $delay = $args{delay} // 0.01;
    $self->delay($delay);

    my $speed = $args{speed} // 'half';
    $self->speed($speed);

    return $self;
}
sub cw {
    my ($self, $degrees) = @_;
    $self->_engage_motor($degrees, 'cw');
}
sub ccw {
    my ($self, $degrees) = @_;
    $self->_engage_motor($degrees, 'ccw');
}
sub delay {
    my ($self, $delay) = @_;
    $self->{delay} = $delay if defined $delay;
    return $self->{delay};
}
sub speed {
    my ($self, $speed) = @_;
    if (defined $speed){
        if (! grep {$speed ne $_} qw(full half)){
            croak "'speed' parameter must be either 'full' or 'half'\n";
        }
        $self->{speed} = $speed;
    }
    return $self->{speed};
}
sub _engage_motor {
    my ($self, $degrees, $direction) = @_;

    if (! defined $degrees){
        croak "a direction in integer degrees must be specified\n";
    }
    if (! defined $direction || $direction !~ /cw/){
        croak "_engage_motor() requires either 'cw' or 'ccw' direction sent in";
    }

    my $step_counter = 0;
    my $pins = $self->_pins;

    for (1..$self->_turns($degrees)) {
        for my $gpio_pin (NUM_PINS) {
            if (STEPPER_SEQUENCE->[$step_counter][$gpio_pin]) {
                write_pin($pins->[$gpio_pin], HIGH);
            }
            else {
                write_pin($pins->[$gpio_pin], LOW);
            }
        }

        if ($direction eq 'cw'){ # clockwise direction
            $step_counter += $self->_phases;

            if ($step_counter >= STEP_COUNT){
                $step_counter = 0;
            }
        }
        else {
            $step_counter += $self->_phases * - 1;

            if ($step_counter < 0) {
                $step_counter = STEP_COUNT + $self->_phases * - 1;
            }
        }

        $self->_wait;
    }

    for (@$pins){
        write_pin($_, LOW);
        pin_mode($_, INPUT);
    }
}
sub _phases {
    return $_[0]->speed eq 'full' ? FULL : HALF;
}
sub _pins {
    my ($self, $pins) = @_;

    if (defined $pins){
        if (@$pins != 4){
            croak "the 'pins' parameter must include an aref with four " .
                  "elements\n";
        }

        for (@$pins){
            pin_mode($_, OUTPUT);
            write_pin($_, LOW);
        }
        $self->{pins} = $pins;
    }

    return $self->{pins};
}
sub _turns {
    # returns the number of "turns" to get to the degrees we want.
    # 64 gear ratio * (degrees / turns for each phase)
    # 5.625/360 degrees for all phases, 11.25/360 degrees for every other phase

    my ($self, $degrees) = @_;
    return $self->_phases == 1
        ? int($degrees / 5.625 + 0.5) * 64
        : int($degrees / 11.25 + 0.5) * 64;
}
sub _wait {
    my ($self) = @_;
    select(undef, undef, undef, $self->delay);
}
sub __vim_placeholder {}

1;
__END__

=head1 NAME

RPi::StepperMotor - Control a typical stepper motor with the Raspberry Pi

=head1 SYNOPSIS

    use warnings;
    use strict;

    use RPi::StepperMotor;

    my $sm = RPi::StepperMotor->new(
        pins => [12, 16, 20, 21],
        speed => 'half',            # optional, default
        delay => 0.01               # optional, default
    );

    $sm->cw(180);  # turn motor 180 degrees clockwise
    $sm->ccw(240); # 240 degrees the other way

    $sm->speed('full'); # skip every second step, turning the motor twice as fast
    $sm->delay(0.5);    # set the delay to a half-second in between steps

=head1 DESCRIPTION

Control a 28BYJ-48 stepper motor through a ULN2003 driver chip.

This is the only setup I've tested. If I come across any more in the future, I
will update this distribution and allow a user to selectively pick which setup
they would like to use.

=head1 METHODS

=head2 new

Instantiates and returns a new L<RPi::StepperMotor> object.

Parameters:

    pins => $aref

Mandatory, Array Reference: The ULN2003 has four data pins, IN1, IN2, IN3 and
IN4. Send in the GPIO pin numbers in the array reference which correlate to the
driver pins in the listed order.

    speed => 'half'|'full'

Optional, String: By default we run in "half speed" mode. Essentially, in this
mode we run through all eight steps. Send in 'full' to double the speed of the
motor. We do this by skipping every other step.

    delay => Float|Int

Optional, Float or Int: By default, between each step, we delay by C<0.01>
seconds. Send in a float or integer for the number of seconds to delay each step
by. The smaller this number, the faster the motor will turn.

=head2 cw($degrees)

Turns the motor in a clockwise direction by a specified number of degrees.

Parameters:

    $degrees

Mandatory, Integer: The number of degrees to turn the motor in a clockwise
direction.

=head2 ccw($degrees)

Turns the motor in a counter-clockwise direction by a specified number of
degrees.

Parameters:

    $degrees

Mandatory, Integer: The number of degrees to turn the motor in a
counter-clockwise direction.

=head2 delay($seconds)

This is the amount of time to delay between each step of the motor. It defaults
to C<0.01> seconds.

Parameters:

    $seconds

Optional, Float|Int: The number of seconds (or fraction of seconds) to delay
between each step of the motor.

Returns:

The currently set delay time.

=head2 speed($speed)

The motor can operate in 'half' speed mode (where all eight steps are used) or
'full' speed mode, where every second step is skipped. 'half' speed mode is more
accurate, but 'full' speed mode is faster.

Parameters:

    $speed

Optional, String: Send in 'full' to skip every second step rendering the motor
twice as fast. The other option is 'half', which is the default setting.

Returns:

The currently set speed.

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2018 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
