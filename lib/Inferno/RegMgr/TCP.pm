package Inferno::RegMgr::TCP;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1.0');    # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Scalar::Util qw( weaken );
use IO::Stream;
use Inferno::RegMgr::Utils qw( run_callback quote attr parse_svc );


use constant PORT_NEW   => 16675;
use constant PORT_FIND  => 26675;
use constant PORT_EVENT => 36675;
use constant KiB        => 1024;


sub new {
    my ($class, $opt) = @_;
    croak '{host} required' if !defined $opt->{host};
    my $self = {
        host        => $opt->{host},
        port_new    => $opt->{port_new}   || PORT_NEW,
        port_find   => $opt->{port_find}  || PORT_FIND,
        port_event  => $opt->{port_event} || PORT_EVENT,
    };
    return bless $self, $class;
}

sub open_event {
    my ($self, $opt) = @_;
    croak '{cb} required' if !defined $opt->{cb};
    my $io = IO::Stream->new({
        host        => $self->{host},
        port        => $self->{port_event},
        cb          => \&_cb_event,
        wait_for    => IN|EOF,
        User_cb     => [ $opt->{cb}, $opt->{method} ],
        Is_connected=> 0,
    });
    return $io;
}

sub _cb_event {
    my ($io, $e, $err) = @_;
    if (!$io->{Is_connected}) {
        if ($e & IN) {
            if ($io->{in_buf} =~ s/\AREADY\n//xms) {
                $io->{Is_connected} = 1;
                $e |= CONNECTED;
            }
            else {
                $err = "Bug in registry: expected 'READY\\n', got '$io->{in_buf}'";
            }
        }
    }
    else {
        if ($err) {
            $e |= EOF;
        }
    }
    if ($e & IN && $io->{in_buf} !~ s/.*\n//xms) {
        $e &= ~IN;
        if (length $io->{in_buf} > KiB) {
            $err = "Bug in registry: got 1 KiB without \\n";
        }
    }
    if ($e & EOF || $err) {
        $io->close();
    }
    if ($e || $err) {
        run_callback( @{ $io->{User_cb} }, $e, $err );
    }
    return;
}

sub open_new {
    my ($self, $opt) = @_;
    croak '{name} required' if !defined $opt->{name};
    croak '{cb} required'   if !defined $opt->{cb};
    my $io = IO::Stream->new({
        host        => $self->{host},
        port        => $self->{port_new},
        cb          => \&_cb_new,
        wait_for    => 0,
        User_cb     => [ $opt->{cb}, $opt->{method} ],
    });
    $io->write(sprintf "%s %s\n",  quote($opt->{name}), attr($opt->{attr}));
    return $io;
}

sub _cb_new {
    my ($io, $e, $err) = @_;
    $io->close();
    run_callback( @{ $io->{User_cb} }, $err );
    return;
}

sub update {
    my ($self, $io, $attr) = @_;
    $io->write(sprintf "%s\n", attr($attr));
    return;
}

sub open_find {
    my ($self, $opt) = @_;
    croak '{cb} required'   if !defined $opt->{cb};
    my $io = IO::Stream->new({
        host        => $self->{host},
        port        => $self->{port_find},
        cb          => \&_cb_find,
        wait_for    => EOF,
        in_buf_limit=> KiB*KiB,
        User_cb     => [ $opt->{cb}, $opt->{method} ],
    });
    $io->write(sprintf "%s\n", attr($opt->{attr}));
    return $io;
}

sub _cb_find {
    my ($io, $e, $err) = @_;
    my $svc;
    if ($e & EOF && !$err) {
        ($svc, $err) = parse_svc($io->{in_buf});
    }
    $io->close();
    run_callback( @{ $io->{User_cb} }, $svc, $err );
    return;
}


1; # Magic true value required at end of module
__END__

=head1 NAME

Inferno::RegMgr::TCP - Access OS Inferno's registry(4) files using TCP ports


=head1 VERSION

This document describes Inferno::RegMgr::TCP version 0.1.0


=head1 SYNOPSIS

 use Scalar::Util qw( weaken );
 use EV;
 use IO::Stream;
 use Inferno::RegMgr::TCP;

 my $reg = Inferno::RegMgr::TCP->new({ host => 'localhost' });

 $reg->open_event({
     cb   => \&cb_event,
 });

 my ($io);
 my $t1 = EV::timer 1, 0, sub {
     $io = $reg->open_new({
         name => 'tcp!example.com!22',
         attr => { proto => 'ssh' },
         cb   => \&cb_new,
     });
     weaken($io);
 };
 my $t2 = EV::timer 2, 0, sub {
     $reg->update($io, { descr => 'example sshd' });
 };
 my $t3 = EV::timer 3, 0, sub {
     $io->close();   # unregister service
 };

 EV::loop;

 sub cb_new {
     my ($err) = @_;
     die "fail to register service or connection to
         registry was lost: $err";
 }
 sub cb_find {
     my ($svc, $err) = @_;
     die "lookup failed: $err" if $err;
     if (!keys %$svc) {
         print "No services found\n";
     }
     for my $name (keys %$svc) {
         print "Found service: $name\n";
         my $attrs = $svc->{$name};
         while (my ($attr, $val) = each %$attrs) {
             print "  $attr = $val\n";
         }
     }
 }
 sub cb_event {
     my ($e, $err) = @_;
     die "failed: $err" if $e & EOF || $err;
     print "connected to registry\n" if $e & CONNECTED;
     if ($e & IN) {
         print "something changed\n";
         $reg->open_find({
             attr => {},     # no query - get all services
             cb   => \&cb_find,
         });
     }
 }

 # --- EXAMPLE OUTPUT:
 # connected to registry
 # something changed
 # Found service: tcp!example.com!22
 #   proto = ssh
 # something changed
 # Found service: tcp!example.com!22
 #   proto = ssh
 #   descr = example sshd
 # something changed
 # No services found

=head1 DESCRIPTION

This module designed as connection plugin for Inferno::RegMgr, and it generally
shouldn't be used manually - only you have to do in usual case is create
new Inferno::RegMgr::TCP object and give to to Inferno::RegMgr.

This module let you access OS Inferno's ndb/registry:
register/update/unregister your services, search for registered services
and get notification on registry change.

All I/O is non-blocking, using IO::Stream. That mean you have to run event
loop (EV::loop) in your code to get this module to work.

Many methods in this module return created IO::Stream object, but in general
case you neither need to keep them nor should access them - they are
completely handled by this module. Main reason to keep these returned
objects - to be able to interrupt their task (using $io->close()).


=head2 Inferno configuration

Example commands to provide access to registry using TCP ports, in a way
compatible with this module:

 listen -A tcp!127.0.0.1!16675 { cat >/mnt/registry/new & }
 listen -A tcp!127.0.0.1!26675 { {
    read >[1=3]; read -o 0 0 <[0=3]; cat >[1=0] <[0=3]
    } <>[3]/mnt/registry/find & }
 listen -A tcp!127.0.0.1!36675 { {
    echo READY; cat
    } </mnt/registry/event & }


=head1 INTERFACE 

=over

=item new()

Create and return Inferno::RegMgr::TCP object.

Accept HASHREF with options:

 host       REQUIRED
 port_new   OPTIONAL, DEFAULT 16675
 port_find  OPTIONAL, DEFAULT 26675
 port_event OPTIONAL, DEFAULT 36675

This hostname and ports will be used by methods open_new(), open_find()
and open_event().


=item open_new()

Register new service in registry.
Create and return IO::Stream object, with connection to {host}:{port_new}.

Accept HASHREF with options:

 name       REQUIRED service name
 attr       OPTIONAL hash with service attrs
 cb         REQUIRED user callback (CODEREF or CLASS name or OBJECT)
 method     OPTIONAL user callback method (if {cb} is CLASS/OBJECT)

User callback will be called only if error happens.
IO::Stream object will be already closed at that point.
Callback params:

 ($err)

Returned IO::Stream object can be used to: update service attrs (using
method update()) and unregister service (using $io->close()).

DO NOT FORGET to weaken() returned IO::Stream object if you will keep it
or to remove it when user callback will be called!


=item update($io, \%attr)

Update attrs for registered service.

 $io        IO::Stream object returned by open_new()
 %attr      can contain only changed/added attrs

Return nothing.


=item open_find()

Lookup for currently registered services in registry.
Create and return IO::Stream object, with connection to {host}:{port_find}.

Accept HASHREF with options:

 attr       OPTIONAL hash with needed service attrs
 cb         REQUIRED user callback (CODEREF or CLASS name or OBJECT)
 method     OPTIONAL user callback method (if {cb} is CLASS/OBJECT)

User callback will be called when search finished.
IO::Stream object will be already closed at that point.
Callback params:

 ($svc, $err)

If $svc undefined, then error $err happens, else $svc will contain HASHREF
with found service names as keys and HASHREF with their attrs as values.

Returned IO::Stream object can be used to: interrupt this search
(using $io->close()).

DO NOT FORGET to weaken() returned IO::Stream object if you will keep it
or to remove it when user callback will be called!


=item open_event()

Get registry change notifications.
Create and return IO::Stream object, with connection to {host}:{port_event}.

Accept HASHREF with options:

 cb         REQUIRED user callback (CODEREF or CLASS name or OBJECT)
 method     OPTIONAL user callback method (if {cb} is CLASS/OBJECT)

Callback params:

 ($e, $err)

User callback will be called on events (CONNECTED, IN and EOF are constants
exported by IO::Stream):

 defined $err       error happens while connecting to registry
 $e & CONNECTED     connected to registry
 $e & IN            registry change detected
 $e & EOF           disconnected from registry

In case of error or EOF IO::Stream object will be already closed when
callback will be called.

Returned IO::Stream object can be used to: stop receiving notifications
(using $io->close()).

DO NOT FORGET to weaken() returned IO::Stream object if you will keep it
or to remove it when user callback will be called on error or EOF!


=back


=head1 DIAGNOSTICS

=over

=item C<< {%s} required >>

Called method require that option in it HASHREF with params.

=back


=head1 CONFIGURATION AND ENVIRONMENT

Inferno::RegMgr::TCP requires no configuration files or environment variables.


=head1 DEPENDENCIES

 version
 IO::Stream


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

It's impossible to unregister (delete) "persist" service.
It's impossible to register different services using different user accounts.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-regmgr-tcp@rt.cpan.org>, or through the web interface at
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
