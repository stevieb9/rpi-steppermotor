package RPi::StepperMotor;

use 5.010;
use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;
use RPi::Const qw(:all);
use WiringPi::API qw(:perl);

our $VERSION = '2.3601';

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

    my $step_counter = 0;
    my $pins = $self->_pins;

    for (1..$self->_turns($degrees)){
        for my $gpio_pin (NUM_PINS){
            if (STEPPER_SEQUENCE->[$step_counter][$gpio_pin]){
                write_pin($pins->[$gpio_pin], HIGH);
            }
            else {
                write_pin($pins->[$gpio_pin], LOW);
            }
        }

        $step_counter += $self->_phases;

        if ($step_counter >= STEP_COUNT){
            $step_counter = 0;
        }

        $self->_wait;
    }

    for (@$pins){
        write_pin($_, LOW);
        pin_mode($_, INPUT);
    }
}
sub ccw {
    my ($self, $degrees) = @_;

    my $step_counter = 0;
    my $pins = $self->_pins;

    for (1..$self->_turns($degrees)){
        for my $gpio_pin (NUM_PINS){
            if (STEPPER_SEQUENCE->[$step_counter][$gpio_pin]){
                write_pin($pins->[$gpio_pin], HIGH);
            }
            else {
                write_pin($pins->[$gpio_pin], LOW);
            }
        }

        $step_counter += $self->_phases * -1;

        if ($step_counter < 0){
            $step_counter = STEP_COUNT + $self->_phases * -1;
        }

        $self->_wait;
    }

    for (@$pins){
        write_pin($_, LOW);
        pin_mode($_, INPUT);
    }
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
sub delay {
    my ($self, $delay) = @_;
    $self->{delay} = $delay if defined $delay;
    return $self->{delay};
}
sub _wait {
    my ($self) = @_;
    select(undef, undef, undef, $self->delay);
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
sub _phases {
    return $_[0]->speed eq 'full' ? FULL : HALF;
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

1;
__END__

=head1 NAME

RPi::StepperMotor - Control a typical stepper motor with the Raspberry Pi

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use RPi::StepperMotor;

    my $foo = RPi::StepperMotor->new();
    ...

=head1 METHODS

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2018 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of RPi::StepperMotor
