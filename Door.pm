# $Date: 2003/09/04 03:38:46 $
# $Id: Door.pm,v 1.18 2003/09/04 03:38:46 asari Exp $

=head1 NAME

IPC::Door - Interface to Solaris (>= 2.6) Door library

=cut

package IPC::Door;

=head1 SYNOPSIS

C<use IPC::Door::Server;>

C<sub serv { return 1 };>

C<$dserver = new IPC::Door::Server('/path/to/door', \&serv);>

C<use IPC::Door::Client;>

C<use POSIX qw( :fcntl_h );>

C<$dclient = new IPC::Door::Client('/path/to/door');>

C<$dclient-E<gt>call($arg, $attr);>

=cut

use 5.006;
use strict;
use warnings;
use Carp;

use POSIX qw[ :fcntl_h uname ];

# Make sure we're on an appropriate version of Solaris
my ($sysname, $release) = (POSIX::uname())[0,2];
die "This module requires Solaris 2.6 and later.\n"
	unless $sysname eq 'SunOS' && $release >= 5.6;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
	'all' => [ qw(
		DOOR_ATTR_MASK
		DOOR_BIND
		DOOR_CALL
		DOOR_CREATE
		DOOR_CRED
		DOOR_DELAY
		DOOR_DESCRIPTOR
		DOOR_EXIT
		DOOR_HANDLE
		DOOR_INFO
		DOOR_INVAL
		DOOR_IS_UNREF
		DOOR_LOCAL
		DOOR_PRIVATE
		DOOR_QUERY
		DOOR_RELEASE
		DOOR_RETURN
		DOOR_REVOKE
		DOOR_REVOKED
		DOOR_UNBIND
		DOOR_UNREF
		DOOR_UNREFSYS
		DOOR_UNREF_ACTIVE
		DOOR_UNREF_MULTI
		DOOR_WAIT
		S_IFDOOR
	) ],
	# door attributes (including "miscellaneous" ones)
	'attr' => [ qw(
		DOOR_ATTR_MASK
		DOOR_UNREF
		DOOR_PRIVATE
		DOOR_UNREF_MULTI
		DOOR_LOCAL
		DOOR_REVOKED
		DOOR_IS_UNREF
		DOOR_DELAY
		DOOR_UNREF_ACTIVE
	) ],
	# attributes for door_desc_t data
	'attr_desc' => [ qw(
		DOOR_DESCRIPTOR
		DOOR_HANDLE
		DOOR_RELEASE
	) ],
	# constant door descriptors
	'desc' => [ qw(
		DOOR_INVAL
		DOOR_QUERY
	) ],
	# errors
	'errors' => [ qw(
		DOOR_WAIT
		DOOR_EXIT
	) ],
	# door operation subcodes
	'subcodes' => [ qw(
		DOOR_CREATE
		DOOR_REVOKE
		DOOR_INFO
		DOOR_CALL
		DOOR_RETURN
		DOOR_CRED
		DOOR_BIND
		DOOR_UNBIND
		DOOR_UNREFSYS
	) ],
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# S_IFDOOR is essential for is_door() function
our @EXPORT = qw( S_IFDOOR );


sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&IPC::Door::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}


our $VERSION = '0.03';

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
See L<IPC::Door::Server>.

=cut

sub new
{
	my ($this, $path, $subref) = @_;
	croak ("Too few arguements for the 'new' method.\n") unless defined($path);
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

C<$dserver->is_door;>

C<IPC::Door::is_door('/path/to/door');>

Subroutine C<is_door> can be called either as an object method or
as a subroutine.

If the former, it determines if the path name assoicated with the object
is a door.
In the latter case, it determines if the path name passed to it is a
door.

=cut

sub is_door ($)
{
	my $self = shift; 
	my $path = (ref($self) =~ m/^IPC::Door/)? $self->{'path'} : $self;

	return ( ((stat $path)[2]) & &S_IFDOOR );
}

=head2 info



=cut

sub info ($)
{
	my $self = shift;
	my $path = (ref($self) =~ m/^IPC::Door/)? $self->{'path'} : $self;

	return __info($path);

}


1;	# end of IPC::Door

__END__


=head1 KNOWN ISSUES

(Roughly in order of importance.)

=over 4

=item 1.  Restriction on C<IPC::Door::Server>

C<IPC::Door::Server> has a very limited capacity.
Right now, the subroutine associated with an C<IPC::Door::Server> object
can only take one scalar and return a scalar.

=item 2.  Some C<door_*> routines not implemented

C<door_bind>, C<door_revoke>, C<door_server_create>, and C<door_unbind>
still need to be implemented.
C<door_info> is only partially implemented.

=item 3.  Memory faults during stress testing

There is a memory management issue, which might be related to item 6.
If the server process gets too much data through a door in a short
period of time, the server script containing that process dies with
B<Memory fault>.

=item 4.  Minimal error checking

There should be more robust error checking throughout.

=item 5.  Limited testing

C<IPC::Door> has been tested on Solaris 8 (with Sun Workshop compiler)
and 9 (with gcc 3.3) (both on SPARC).

If you can help me test on earlier versions of Solaris or Solaris on
x86, pleas let me know.

=item 6.  Doesn't play well with threaded perl

It doesn't work on threaded C<perl>.
In my limited testing with threaded C<perl>, C<IPC::Door> failed with
B<Memory fault>.

=item 7.  A little inconsistent XS code

I'm still a beginner at XS (some may argue also at Perl), so the code,
especially the XS portion, can be improved.
Any suggestions are welcome.

=back

=head1 SEE ALSO

L<IPC::Door::Client>, L<IPC::Door::Server>

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
