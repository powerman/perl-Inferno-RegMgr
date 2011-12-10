package Inferno::RegMgr::Monitor;

use warnings;
use strict;
use Carp;

use version 0.77; our $VERSION = version->declare('0.1.0'); # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken );
use Inferno::RegMgr::Utils qw( run_callback );

use Inferno::RegMgr::Lookup;


sub new {
    my ($class, $opt) = @_;
    my $self = {
        lookup      => undef,
        cb_add      => $opt->{cb_add},
        cb_del      => $opt->{cb_del},
        cb_mod      => $opt->{cb_mod},
        method_add  => $opt->{method_add},
        method_del  => $opt->{method_del},
        method_mod  => $opt->{method_mod},
        manager     => undef,
        cur         => {},
    };
    bless $self, $class;
    weaken( my $this = $self );
    $self->{lookup} = Inferno::RegMgr::Lookup->new({
        attr    => $opt->{attr},
        cb      => sub { $this->_cb_monitor(@_) },
    });
    return $self;
}

sub START {
    my ($self) = @_;
    $self->{manager}->attach( $self->{lookup} );
    return;
}

sub _cb_monitor {
    my ($self, $svc) = @_;
    my @prev = keys %{ $self->{cur} };
    for my $name (@prev) {
        if (exists $svc->{ $name }) {
            my $attr = delete $svc->{ $name };
            if (_is_differ($self->{cur}{ $name }, $attr)) {
                $self->{cur}{ $name } = $attr;
                if (defined $self->{cb_mod}) {
                    run_callback( $self->{cb_mod}, $self->{method_mod}, $name => $attr );
                }
            }
        }
        else {
            my $attr = delete $self->{cur}{ $name };
            if (defined $self->{cb_del}) {
                run_callback( $self->{cb_del}, $self->{method_del}, $name => $attr );
            }
        }
    }
    for my $name (keys %{ $svc }) {
        my $attr = $svc->{ $name };
        $self->{cur}{ $name } = $attr;
        if (defined $self->{cb_add}) {
            run_callback( $self->{cb_add}, $self->{method_add}, $name => $attr );
        }
    }
    return;
}

sub _is_differ {
    my ($h1, $h2) = @_;
    return 1 if keys %{ $h1 } != keys %{ $h2 };
    for my $key (keys %{ $h1 }) {
        return 1 if !exists $h2->{ $key };
        return 1 if $h1->{ $key } ne $h2->{ $key };
    }
    return 0;
}

sub STOP {
    my ($self) = @_;
    # Inferno::RegMgr::Lookup may already detach itself (after finishing search).
    if ($self->{lookup}{manager}) {
        $self->{manager}->detach( $self->{lookup} );
    }
    return;
}

sub REFRESH {
    my ($self) = @_;
    $self->STOP();
    $self->START();
    return;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Inferno::RegMgr::Monitor - Monitor services in OS Inferno's registry(4)


=head1 VERSION

This document describes Inferno::RegMgr::Monitor version 0.1.0


=head1 SYNOPSIS

See L<Inferno::RegMgr> for usage example.


=head1 DESCRIPTION

This module designed as task plugin for Inferno::RegMgr and can't be used without Inferno::RegMgr.

To monitor services with some attributes set needed attributes and callbacks
while creating new() Inferno::RegMgr::Monitor object, then attach() it to Inferno::RegMgr.
You only need to keep reference to Inferno::RegMgr::Monitor object if you will need
to interrupt this monitoring using detach().


=head1 INTERFACE 

=over

=item new()

Create and return Inferno::RegMgr::Monitor object.

Accept HASHREF with options:

 attr       OPTIONAL hash with wanted service attrs
 cb_add     OPTIONAL user callback (CODEREF or CLASS name or OBJECT)
 method_add OPTIONAL user callback method (if {cb} is CLASS/OBJECT)
 cb_mod     OPTIONAL user callback (CODEREF or CLASS name or OBJECT)
 method_mod OPTIONAL user callback method (if {cb} is CLASS/OBJECT)
 cb_del     OPTIONAL user callback (CODEREF or CLASS name or OBJECT)
 method_del OPTIONAL user callback method (if {cb} is CLASS/OBJECT)

On each registry change new search for services will be done (using
Inferno::RegMgr::Lookup), and if you provided callbacks they will be called
when new service registered (add), existing service will change it attributes
(mod), service unregistered (del).

In all cases user callback will be called with parameters:

 ($service_name, \%service_attr)


=back


=head1 DIAGNOSTICS

None.


=head1 CONFIGURATION AND ENVIRONMENT

Inferno::RegMgr::Monitor requires no configuration files or environment variables.


=head1 DEPENDENCIES

 version


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-regmgr-monitor@rt.cpan.org>, or through the web interface at
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
