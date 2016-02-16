package Inferno::RegMgr::Service;
use 5.010001;
use warnings;
use strict;
use utf8;
use Carp;

our $VERSION = 'v0.1.7';

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

=encoding utf8

=head1 NAME

Inferno::RegMgr::Service - Register your service in OS Inferno's registry(4)


=head1 VERSION

This document describes Inferno::RegMgr::Service version 0.1.7


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


=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/powerman/perl-Inferno-RegMgr/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

L<https://github.com/powerman/perl-Inferno-RegMgr>

    git clone https://github.com/powerman/perl-Inferno-RegMgr.git

=head2 Resources

=over

=item * MetaCPAN Search

L<https://metacpan.org/search?q=Inferno-RegMgr>

=item * CPAN Ratings

L<http://cpanratings.perl.org/dist/Inferno-RegMgr>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Inferno-RegMgr>

=item * CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Inferno-RegMgr>

=item * CPANTS: A CPAN Testing Service (Kwalitee)

L<http://cpants.cpanauthors.org/dist/Inferno-RegMgr>

=back


=head1 AUTHOR

Alex Efros E<lt>powerman@cpan.orgE<gt>


=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2009-2010 by Alex Efros E<lt>powerman@cpan.orgE<gt>.

This is free software, licensed under:

  The MIT (X11) License


=cut
