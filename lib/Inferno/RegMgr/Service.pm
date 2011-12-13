package Inferno::RegMgr::Service;

use warnings;
use strict;
use Carp;

# update POD & Changes & README
use version; our $VERSION = qv('0.1.0');

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken );
use EV;


use constant RETRY => 1;    # sec, delay between re-connections


sub new {
    my ($class, $opt) = @_;
    my $self = {
        name    => $opt->{name},
        attr    => $opt->{attr},
        manager => undef,
        io      => undef,
        t       => undef,
    };
    return bless $self, $class;
}

sub START {
    my ($self) = @_;
    $self->{io} = $self->{manager}{registry}->open_new({
        name    => $self->{name},
        attr    => $self->{attr},
        cb      => $self,
        method  => '_cb_new',
    });
    weaken( $self->{io} );
    return;
}

sub _cb_new { ## no critic(ProhibitUnusedPrivateSubroutines)
    my ($self, $err) = @_;
    $self->{t} = EV::timer RETRY, 0, sub { $self->START() };
    return;
}

sub STOP {
    my ($self) = @_;
    if (defined $self->{io}) {
        $self->{io}->close();
    }
    $self->{t} = undef;
    return;
}

sub update {
    my ($self, $attrs) = @_;
    while (my ($attr, $val) = each %{ $attrs }) {
        $self->{attr}{ $attr } = $val;
    }
    if (defined $self->{io}) {
        $self->{manager}{registry}->update($self->{io}, $attrs);
    }
    return;
}

sub REFRESH {}


1; # Magic true value required at end of module
__END__

=head1 NAME

Inferno::RegMgr::Service - Register your service in OS Inferno's registry(4)


=head1 VERSION

This document describes Inferno::RegMgr::Service version 0.1.0


=head1 SYNOPSIS

See L<Inferno::RegMgr> for usage example.


=head1 DESCRIPTION

This module designed as task plugin for Inferno::RegMgr and can't be used without Inferno::RegMgr.

To register your service set service name and attributes while creating
new() Inferno::RegMgr::Service object, then attach() it to Inferno::RegMgr. You may wanna
keep reference to Inferno::RegMgr::Service object to update() service attributes
and/or unregister service using detach().


=head1 INTERFACE 

=over

=item new()

Create and return Inferno::RegMgr::Service object.

Accept HASHREF with options:

 name       REQUIRED service name
 attr       OPTIONAL hash with service attrs


=item update()

Update service attributes.

Accept HASHREF with attributes which should be added/changed.

Return nothing.


=back


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

Inferno::RegMgr::Service requires no configuration files or environment variables.


=head1 DEPENDENCIES

 EV


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-regmgr-service@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Alex Efros  C<< <powerman-asdf@ya.ru> >>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Alex Efros C<< <powerman-asdf@ya.ru> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
