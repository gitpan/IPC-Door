package IPC::Door::Server;

use 5.006;
use strict;
use warnings;

use POSIX qw[ :fcntl_h ];
use IPC::Door;

our @ISA = qw[ IPC::Door ];

1;	# end of IPC::Door::Server

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

Right now, C<&mysub> must be a subroutine that takes one scalar (which
is typecast to a double) and returns one scalar (which is also typecast
to a double).
Since the argument(s) and return value(s) must be compiled into the
shared object file, this restriction will not be too much more liberal.
(Perhaps we can pass references back and forth.)

=head2 SPECIAL VARIABLES

One a door client calls an C<IPC::Door::Server> object, it sets 5
special variables as a result of C<door_cred>(3DOOR) call.
These are:
C<$main::DOOR_CLIENT_EUID>,
C<$main::DOOR_CLIENT_EGID>,
C<$main::DOOR_CLIENT_RUID>,
C<$main::DOOR_CLIENT_RGID>,
C<$main::DOOR_CLIENT_PID>,
and their meanings should be pretty self-explanatory;
i.e., the client process's effective user id, effective group id,
real user id, real group id, and process id.

If it makes sense, you can discriminate against client processes
inside C<&mysub>.
(It doesn't make much sense to do anything with these variables outside
&mysub, anyway.)

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

Copyright 2003 by ASARI Hirotsugu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
