package IPC::Door::Server;
#$Id: Server.pm,v 1.9 2004/05/01 08:01:20 asari Exp $

use 5.006;
use strict;
use warnings;

use POSIX qw[ :fcntl_h ];
use IPC::Door;

our @ISA = qw[ IPC::Door ];

1;    # end of IPC::Door::Server

__END__

=head1 NAME

IPC::Door::Server - door server object for Solaris (>= 2.6)

=head2 SYNOPSIS

C<use IPC::Door::Server;>

C<$door = '/path/to/door';>

C<$dserver = new IPC::Door::Server($door, \&mysub);>

=head1 DESCRIPTION

C<IPC::Door::Server> is a Perl class for door servers.
It creates a door C<$door> and listens to client requests through it.

When a door client sends a request through its door,
the C<IPC::Door::Server> passes the data to C<&mysub>, and sends its
return value to the client.

=head2 SERVER PROCESS

Each C<IPC::Door::Server> object is associated with a server process
(C<&mysub> throughout this documentation).
C<&mysub> must take exactly one scalar and return exactly one scalar.

Currently, these arguments can't be a reference or any other data
structure.
See <IPC::Door/"KNOWN ISSUES">.

=head2 SPECIAL VARIABLES

Once a door client calls an C<IPC::Door::Server> object, it sets 5
special variables as a result of C<door_cred>(3DOOR) call.
These are:
C<$main::DOOR_CLIENT_EUID>,
C<$main::DOOR_CLIENT_EGID>,
C<$main::DOOR_CLIENT_RUID>,
C<$main::DOOR_CLIENT_RGID>,
C<$main::DOOR_CLIENT_PID>,
and their meanings should be pretty self-explanatory.

If it makes sense, you can discriminate against client processes
inside C<&mysub>.
(It doesn't make much sense to do anything with these variables outside
&mysub, anyway.)

Note that if there are more than one door clients are connected
to a single C<IPC::Door::Server> process, the race condition exists
and these variables may hold incorrect values.

=head1 SEE ALSO

L<IPC::Door>, L<IPC::Door::Client>

L<door_bind>(3DOOR),
L<door_call>(3DOOR),
L<door_create>(3DOOR),
L<door_cred>(3DOOR),
L<door_info>(3DOOR),
L<door_return>(3DOOR),
L<door_revoke>(3DOOR),
L<door_server_create>(3DOOR),
L<door_unbind>(3DOOR),

L<UNIX Network Programming Volume 2: Interprocess Communications|http://www.kohala.com/start/unpv22e/unpv22e.html>

L<Solaris Internals: Core Kernel Architecture|http://www.solarisinternals.com>

=head1 AUTHOR

ASARI Hirotsugu <asarih at cpan dot org>

L<http://www.asari.net/perl>

=head1 COPYRIGHT AND LICENSE

Copyright 2003, 2004 by ASARI Hirotsugu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
