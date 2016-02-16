[![Build Status](https://travis-ci.org/powerman/perl-Inferno-RegMgr.svg?branch=master)](https://travis-ci.org/powerman/perl-Inferno-RegMgr)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-Inferno-RegMgr/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-Inferno-RegMgr?branch=master)

# NAME

Inferno::RegMgr - Keep connection to OS Inferno's registry(4) and it tasks

# VERSION

This document describes Inferno::RegMgr version 0.1.7

# SYNOPSIS

    use EV;
    use Inferno::RegMgr;
    use Inferno::RegMgr::TCP;
    use Inferno::RegMgr::Service;
    use Inferno::RegMgr::Lookup;
    use Inferno::RegMgr::Monitor;

    my $conn = Inferno::RegMgr::TCP->new({ host => '127.0.0.1' });
    my $regmgr = Inferno::RegMgr->new( $conn );

    my $srv1 = Inferno::RegMgr::Service->new({
        name => 'srv1',
        attr => \%attr1,
    });
    my $srv2 = Inferno::RegMgr::Service->new({
        name => 'srv2',
        attr => \%attr2,
    });
    $regmgr->attach( $srv1 );
    $regmgr->attach( $srv2 );

    $regmgr->detach( $srv1 );   # some time later

    $regmgr->attach(
        Inferno::RegMgr::Lookup->new({attr=>\%srchattr,cb=>\&srch});
    );

    my $mon  = Inferno::RegMgr::Monitor->new({
        attr   => \%monitorattr,
        cb_add => \&registered,
        cb_del => \&unregistered,
    });
    $regmgr->attach( $mon );

    EV::loop;

# DESCRIPTION

Using OS Inferno registry(4) is simple, but in case connection to registry
become broken (because of network issues or even registry restart) you
have to manually reconnect to registry and restore state (register your
services once again, find out changes in services you're using now, etc.).
Inferno::RegMgr will do this work for you automatically.

Inferno::RegMgr has plugin-based architecture. There two plugin types:
connection (which handle I/O to registry server) and task (like
registering your service or searching for services).

    Connection plugins:
       Inferno::RegMgr::TCP
    Task plugins:
       Inferno::RegMgr::Service
       Inferno::RegMgr::Lookup
       Inferno::RegMgr::Monitor

When you creating new Inferno::RegMgr object, you should provide
connection plugin, which will be used to access registry. Next you can
attach/detach to this Inferno::RegMgr object any amount of any task
plugins. Inferno::RegMgr will guarantee all these tasks will work when
connection to registry is available, and task's state will be
automatically restored after reconnecting to registry server.

This is EV-based module, so you have to run EV::loop in your code to use this
module.

# INTERFACE 

- new( $connection\_plugin )

    Create new Inferno::RegMgr object, configured to use $connection\_plugin to
    access registry. (All task plugins attached to this object also will use
    that connection plugin.)

    If you lose all references to returned Inferno::RegMgr object all attached
    tasks will be stopped and detached, all memory used by all plugins will be
    freed (unless you will keep references to some plugins).

    Return Inferno::RegMgr object.

- attach( $task\_plugin )

    Attached plugin will start working as soon as connection to registry will
    be available. Reference to this plugin will be stored in Inferno::RegMgr
    object until that plugin will be detach()ed.

    You need to keep reference to attached task plugin only if you wanna stop
    (detach()) it later or if that plugin object provide additional features.

    Return nothing.

- detach( $task\_plugin )

    Given $task\_plugin should be same as used in attach() method before.
    It will be stopped and detached (but it still may keep some state, which
    will may be reused if that plugin will be attach()ed again).

    Return nothing.

# FOR PLUGIN DEVELOPERS

## CONNECTION PLUGIN INTERFACE

- open\_new()
- update()
- open\_find()
- open\_event()

    These methods must be provided by connection plugin. Their parameters and
    return values listed at [Inferno::RegMgr::TCP](https://metacpan.org/pod/Inferno::RegMgr::TCP).

## TASK PLUGIN INTERFACE

- {manager}

    This property will be set in plugin object to reference to Inferno::RegMgr
    object in attach(), and will be set to undef in detach(). Plugin should
    use it to access Inferno::RegMgr object it attached to.

    Usually plugin need Inferno::RegMgr object to access it property
    {registry}, which contain reference to connection plugin object used to
    access registry.  Another uses of Inferno::RegMgr object from task plugin
    is to detach() itself or attach() another task plugins.

- START()
- STOP()
- REFRESH()

    These methods must be provided by task plugin. Their doesn't has
    parameters and doesn't return anything. Inferno::RegMgr will call START()
    when connection to registry become available, STOP() when connection to
    registry lost, and REFRESH() when registry state changes (new service
    registered, server change it attributes, service unregistered).

# DIAGNOSTICS

- `already attached`

    You're trying to attach() object which is already attached to this or another
    Inferno::RegMgr object.

- `not attached to this manager`

    You're trying to detach() object which isn't attached to this
    Inferno::RegMgr object.

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-Inferno-RegMgr/issues](https://github.com/powerman/perl-Inferno-RegMgr/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-Inferno-RegMgr](https://github.com/powerman/perl-Inferno-RegMgr)

    git clone https://github.com/powerman/perl-Inferno-RegMgr.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=Inferno-RegMgr](https://metacpan.org/search?q=Inferno-RegMgr)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/Inferno-RegMgr](http://cpanratings.perl.org/dist/Inferno-RegMgr)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/Inferno-RegMgr](http://annocpan.org/dist/Inferno-RegMgr)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=Inferno-RegMgr](http://matrix.cpantesters.org/?dist=Inferno-RegMgr)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/Inferno-RegMgr](http://cpants.cpanauthors.org/dist/Inferno-RegMgr)

# AUTHOR

Alex Efros &lt;powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2009-2010 by Alex Efros &lt;powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
