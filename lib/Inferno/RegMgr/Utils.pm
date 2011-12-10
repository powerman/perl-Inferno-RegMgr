package Inferno::RegMgr::Utils;

use warnings;
use strict;
use Carp;

use version 0.77; our $VERSION = version->declare('0.1.2'); # update POD & Changes & README

# update DEPENDENCIES in POD & Makefile.PL & README
use Perl6::Export::Attrs;


sub quote :Export {
    my ($s) = @_;
    if ($s =~ / \s | ' | \A\z /xms) {
        $s =~ s/'/''/xmsg;
        $s = "'$s'";
    }
    return $s;
}

sub unquote :Export {
    my ($s) = @_;
    if ($s =~ s/\A'(.*)'\z/$1/xms) {
        $s =~ s/''/'/xmsg;
    }
    return $s;
}

sub attr :Export {
    my ($attr) = @_;
    my @s;
    while (my ($k, $v) = each %{ $attr || {} }) {
        push @s, sprintf '%s %s', quote($k), quote($v);
    }
    return join q{ }, @s;
}

my $qword = qr{( [^'\s]+ | '[^']*(?:''[^']*)*' )}xms;
sub parse_svc :Export {
    my ($s) = @_;
    return ({}, undef) if $s eq q{};
    return (undef, 'no \\n at end') if $s !~ /\n\z/xms;
    my %svc;
    for my $line (split /\n/xms, $s) {
        my $errmsg = "can't parse service: $line";
        return (undef, $errmsg) if $line !~ s/\A$qword//xms;
        my $name = unquote($1);
        my %attr;
        while (length $line) {
            return (undef, $errmsg) if $line !~ s/\s$qword\s$qword//xms;
            my ($attr, $value) = ($1, $2);
            $attr{ unquote($attr) } = unquote($value);
        }
        $svc{$name} = \%attr;
    }
    return (\%svc, undef);
}

my $STDREF = qr{SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE}xms;
sub run_callback :Export { ## no critic (RequireArgUnpacking)
    croak  'usage: run_callback( CB [, METHOD [, @ARGS]] )'    if @_ < 1;
    my ($cb, $method) = (shift, shift);
    my $cb_type
        = !ref($cb)                         ? 'CLASS'
        : ref($cb) eq 'CODE'                ? 'CODE'
        : ref($cb) !~ m{\A$STDREF\z}xmso    ? 'OBJECT'
        :                                     undef
        ;
    if ($cb_type eq 'CLASS' || $cb_type eq 'OBJECT') {
        $cb->$method(@_);
    }
    elsif ($cb_type eq 'CODE') {
        $cb->(@_);
    }
    else {
        croak qq{run_callback: wrong CB $cb};
    }
    return;
}



1; # Magic true value required at end of module
__END__

=head1 NAME

Inferno::RegMgr::Utils - Internal module for use by other Inferno::RegMgr::*


=head1 VERSION

This document describes Inferno::RegMgr::Utils version 0.1.2


=head1 SYNOPSIS

 run_callback( \&sub );
 run_callback( 'CLASS', 'some_method' );
 run_callback( $obj, 'some_method', $foo, "bar" );


=head1 DESCRIPTION

Internal module for use by other Inferno::RegMgr::*.


=head1 INTERFACE 

=over

=item run_callback( CB, METHOD, ARGS )

Run callback in Perl6 style (see http://dev.perl.org/perl6/rfc/321.html).

 CB         REQUIRED. code ref OR object OR class name
 METHOD     REQUIRED. method name for CB
 ARGS       OPTIONAL. list with params for CB
 NOTE: METHOD required only if CB is object or class name.

Return: nothing.

=item quote()

=item unquote()

=item attr()

=item parse_svc()

Helpers to process service list used by registry server.


=back


=head1 DIAGNOSTICS

=over

=item C<< usage: run_callback( CB [, METHOD [, @ARGS]] ) >>

run_callback() was executed without params.

=item C<< run_callback: wrong CB ... >>

First param of run_callback() isn't one of:

 CODE ref
 OBJECT
 CLASS name


=back


=head1 CONFIGURATION AND ENVIRONMENT

Inferno::RegMgr::Utils requires no configuration files or environment variables.


=head1 DEPENDENCIES

 version
 Perl6::Export::Attrs


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-regmgr-utils@rt.cpan.org>, or through the web interface at
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
