# $Date: 2003/08/29 04:22:24 $
# $Id: Door.pm,v 1.11 2003/08/29 04:22:24 asari Exp $

=head1 NAME

IPC::Door - Interface to Solaris (>= 2.6) Door library

=cut

package IPC::Door;

=head1 SYNOPSIS

C<use IPC::Door;>

C<use Fctnl;>

C<sub serv { return 1 };>

C<$dserver = new IPC::Door::Server('/path/to/door', \&serv);>

C<sysopen(DOOR, '/path/to/door', O_WRONLY);>

C<$dclient = new IPC::Door::Client('/path/to/door');>

C<$dclient-E<gt>call($arg);>

=cut

use 5.006;
use strict;
use warnings;

use Carp;


# Make sure we're on an appropriate version of Solaris
use POSIX qw[ uname ];
my ($sysname, $release) = (POSIX::uname())[0,2];
die "This module requires Solaris 2.6 and later.\n"
	unless $sysname eq 'SunOS' && $release >= 5.6;

require Exporter;

our @ISA = qw(Exporter);

our $VERSION = '0.02';

require XSLoader;
XSLoader::load('IPC::Door', $VERSION);

=head1 ABSTRACT

IPC::Door is a Perl extension to the door library present in
Solaris 2.6 and later.

=cut

=head1 COMMON CLASS METHODS

=head2 new

The method C<new> initializes the object, taking a mandatory argument
C<$path>.
Each C<IPC::Door::*> object is thus associated with a door
through which it communicates with a server (if the object is a
C<::Client>) or a client (if the object is a C<::Server>).

In addition, the C<::Server> object requires a reference to a code block
C<$codeblock>, which will be a part of the server process upon
compilation.

=head3 Caveat to new

Right now, C<$coderef> is completely ignored, but when the code matures,
the door server will execute C<&{$coderef}>.
Instead, a special routine C<&main::serv> must be defined.
It will be passed one argument, and it must return a scalar.
The return value will be evaluated as a double.

=cut

sub new
{
	my ($this, $path, $subref) = @_;
	my $class = ref($this) || $this;
	my $self = { 'path' => $path };


	if ( $class eq 'IPC::Door::Server' ) {
		unless ( defined ($subref) ) {
			carp "Too few arguments for the 'new' method.\n";
		}
		bless $self, $class;
		$self->{ 'callback' } = $subref;
		die "Can't create door to $path: $!\n" unless ( $self->__create($path, $subref) == 0 );
	}
	elsif ( $class eq 'IPC::Door::Client' )
	{
		bless $self, $class;
	}

	return $self;
}


=head2 is_door

C<is_door> returns 1 if the file associated with the
C<IPC::Door::*> object is a door.

=cut

sub is_door ($)
{
	my $self = shift; 
	my $path = $self->{'path'};

	my $door_bitmask = 0xD000;	# as defined in /usr/include/sys/stat.h

	return ( (((stat $path)[2]) & $door_bitmask) == $door_bitmask );
}


1;	# end of IPC::Door

######################################################################

=head1 CLASSES

=head2 IPC::Door::Server

C<IPC::Door::Server> is the door server.
When initialized with C<new>, it will create a door that it listens to.

=cut

######################################################################
package IPC::Door::Server;

use 5.006;
use strict;
use warnings;

our @ISA = qw[ IPC::Door ];

1;	# end of IPC::Door::Server

######################################################################

=head2 IPC::Door::Client

C<IPC::Door::Client> is the door client.

=cut

######################################################################
package IPC::Door::Client;

use 5.006;
use strict;
use warnings;

our @ISA = qw[ IPC::Door ];

sub call {
	my $self = shift;
	my $path = $self->{'path'};

	my $arg = shift;

	return $self->__call($path, $arg);
}

1;	# end of IPC::Door::Client

__END__

######################################################################

=head1 KNOWN ISSUES

=over 4

=item 1.

C<IPC::Door::Server> has a very limited capacity.  See L<"Caveat to new">.

=item 2.

Only a few C<door_*> system calls are implemented.

=item 3.

Very minimal error checking.

=item 4.

C<IPC::Door> has been tested on Solaris 8 (with Sun Workshop compiler)
and 9 (with gcc 3.3) (both on SPARC).

If you can help me test on earlier versions of Solaris or Solaris on
x86, pleas let me know.

=item 5.

It doesn't work on threaded Perl.

=item 6.

There is a memory management issue, which might be related to item 5.
If the server process gets too much data through a door in a short
period of time, the server script containing that process dies with
I<Memory fault>.

=head1 SEE ALSO

L<door_bind(3DOOR)>,
L<door_call(3DOOR)>,
L<door_create(3DOOR)>,
L<door_cred(3DOOR)>,
L<door_info(3DOOR)>,
L<door_return(3DOOR)>,
L<door_revoke(3DOOR)>,
L<door_server_create(3DOOR)>,
L<door_unbind(3DOOR)>,

=head1 AUTHOR

ASARI Hirotsugu <asarih at cpan dot org>

L<http://www.asari.net/perl>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by ASARI Hirotsugu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
