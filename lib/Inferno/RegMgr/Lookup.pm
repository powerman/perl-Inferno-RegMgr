package Inferno::RegMgr::Lookup;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1.0');    # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken );
use EV;
use Inferno::RegMgr::Utils qw( run_callback );


use constant RETRY => 1;    # sec, delay between re-connections


sub new {
    my ($class, $opt) = @_;
    my $self = {
        attr    => $opt->{attr},
        cb      => $opt->{cb},
        method  => $opt->{method},
        manager => undef,
        io      => undef,
        t       => undef,
    };
    return bless $self, $class;
}

sub START {
    my ($self) = @_;
    $self->{io} = $self->{manager}{registry}->open_find({
        attr    => $self->{attr},
        cb      => $self,
        method  => '_cb_find',
    });
    weaken( $self->{io} );
    return;
}

sub _cb_find { ## no critic(ProhibitUnusedPrivateSubroutines)
    my ($self, $svc, $err) = @_;
    if ($svc) {
        $self->{manager}->detach( $self );
        run_callback( $self->{cb}, $self->{method}, $svc );
    }
    else {
        $self->{t} = EV::timer RETRY, 0, sub { $self->START() };
    }
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

sub REFRESH {}


1; # Magic true value required at end of module
__END__

=head1 NAME

Inferno::RegMgr::Lookup - Search services in OS Inferno's registry(4)


=head1 VERSION

This document describes Inferno::RegMgr::Lookup version 0.1.0


=head1 SYNOPSIS

See L<Inferno::RegMgr> for usage example.


=head1 DESCRIPTION

This module designed as task plugin for Inferno::RegMgr and can't be used without Inferno::RegMgr.

To search for services with some attributes set needed attributes while
creating new() Inferno::RegMgr::Lookup object, then attach() it to Inferno::RegMgr. You only
need to keep reference to Inferno::RegMgr::Lookup object if you will need to
interrupt this search before receiving results using detach().

This module will automatically detach() itself from Inferno::RegMgr before calling
user callback with search results.


=head1 INTERFACE 

=over

=item new()

Create and return Inferno::RegMgr::Lookup object.

Accept HASHREF with options:

 attr       OPTIONAL hash with wanted service attrs
 cb         REQUIRED user callback (CODEREF or CLASS name or OBJECT)
 method     OPTIONAL user callback method (if {cb} is CLASS/OBJECT)

If there will be no option attr or it value will be empty hash - all
services will be retured.

If some attribute value will be '*' then all services which has that
attribute with any value will be returned.

After receiving search results user callback will be called with
parameters (keys in hash are found service names and values are attributes
of these services):

 (\%services)


=back


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

Inferno::RegMgr::Lookup requires no configuration files or environment variables.


=head1 DEPENDENCIES

 EV


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-regmgr-lookup@rt.cpan.org>, or through the web interface at
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
