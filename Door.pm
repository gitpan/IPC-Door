# $Id: Door.pm,v 1.33 2004/05/06 03:08:45 asari Exp $

=head1 NAME

IPC::Door - Interface to Solaris (>= 2.6) Door library

=head1 SYNOPSIS

The server script:

    use IPC::Door::Server;
    use Fcntl;
    my  $door = "/path/to/door";
    my  $dserver = new IPC::Door::Server($door, &mysub);
    while (1) {
        die "$door disappeared: $!\n" unless IPC::Door::is_door($door);
        sysopen( DOOR, $door, O_WRONLY ) || die "Can't write to $door: $!\n";
        close DOOR;
        select undef, undef, undef, 0.2;
    }

    sub mysub {
        my $arg = shift;
        # do something
        my $ans;
        return $ans;
    }

The client script:

    use IPC::Door::Client;
        use Fcntl;
        my  $door = "/path/to/door";
        my  $dclient = new IPC::Door::Client($door);
        my  $data;
        my  $answer = $client->call($data, O_RDWR);

=cut

package IPC::Door;

use 5.006;
use strict;
use warnings;
use Carp;

use POSIX qw[ :fcntl_h uname ];

# Make sure we're on an appropriate version of Solaris
my ($sysname, $release) = (POSIX::uname())[ 0, 2 ];
die "This module requires Solaris 2.6 and later.\n"
  unless $sysname eq 'SunOS' && $release >= 5.6;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
    'all' => [
        qw(
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
          )
    ],

    # door attributes (including "miscellaneous" ones)
    'attr' => [
        qw(
          DOOR_ATTR_MASK
          DOOR_UNREF
          DOOR_PRIVATE
          DOOR_UNREF_MULTI
          DOOR_LOCAL
          DOOR_REVOKED
          DOOR_IS_UNREF
          DOOR_DELAY
          DOOR_UNREF_ACTIVE
          )
    ],

    # attributes for door_desc_t data
    'attr_desc' => [
        qw(
          DOOR_DESCRIPTOR
          DOOR_HANDLE
          DOOR_RELEASE
          )
    ],

    # constant door descriptors
    'desc' => [
        qw(
          DOOR_INVAL
          DOOR_QUERY
          )
    ],

    # errors
    'errors' => [
        qw(
          DOOR_WAIT
          DOOR_EXIT
          )
    ],

    # door operation subcodes
    'subcodes' => [
        qw(
          DOOR_CREATE
          DOOR_REVOKE
          DOOR_INFO
          DOOR_CALL
          DOOR_RETURN
          DOOR_CRED
          DOOR_BIND
          DOOR_UNBIND
          DOOR_UNREFSYS
          )
    ],
);

our @EXPORT_OK = (@{ $EXPORT_TAGS{'all'} });

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

our $VERSION = '0.08';

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

In addition, the C<IPC::Door::Server> object requires a reference to a
code block C<$codeblock>, which will be a part of the server process upon
compilation.
See L<IPC::Door::Server>.

=cut

sub new {
    my ($this, $path, $subref) = @_;
    croak("Too few arguements for the 'new' method.\n") unless defined($path);
    my $class = ref($this) || $this;
    my $self = { 'path' => $path };

    if ($class eq 'IPC::Door::Server') {
        unless (defined($subref)) {
            carp "Too few arguments for the 'new' method.\n";
        }
        bless $self, $class;
        $self->{'callback'} = $subref;
        die "Can't create door to $path: $!\n"
          unless $self->__create($path, $subref);
    }
    elsif ($class eq 'IPC::Door::Client') {
        bless $self, $class;
    }

    return $self;
}

=head2 is_door

    $dserver-E<gt>is_door;

    IPC::Door::is_door('/path/to/door');

Subroutine C<is_door> can be called either as an object method or
as a subroutine.

If the former, it determines if the path name assoicated with the object
is a door.
In the latter case, it determines if the path name passed to it is a
door.

=cut

# Note that is_door() is implemented in C.

=head2 info

    my ($target, $attr, $uniq) = IPC::Door::info($door);

Subroutine C<info> takes the path to a door and return array C<(target, attributes, uniquifer)>.
C<target> is the server process id that is listening through the door,
C<attributes> is the integer that represents the attributes of the door
(see L<Door attributes>),
and C<uniquifer> is the system-wide unique number associated with the
door.

=head3 Door attributes

When testing for a door's attributes, it is convenient to import
some symbols:

C<use IPC::Door qw( :attr );>

This imports symbols
C<DOOR_ATTR_MASK> C<DOOR_UNREF> C<DOOR_PRIVATE> C<DOOR_UNREF_MULTI>
C<DOOR_LOCAL> C<DOOR_REVOKED> C<DOOR_IS_UNREF> C<DOOR_DELAY>
C<DOOR_UNREF_ACTIVE>

=cut

sub info ($) {
    my $self = shift;
    my $path = (ref($self) =~ m/^IPC::Door/) ? $self->{'path'} : $self;

    return __info($path);

}

sub DESTROY {
    my $self = shift;

    ;
}

1;    # end of IPC::Door

__END__

=head1 KNOWN ISSUES

=over 4

=item 1.  Restriction on passed data

The doors created by C<IPC::Door::*> can only pass strings.
If it's a normal scalar in the Perl sense, Perl does the conversion when
a number is expected.

Note that passing references won't work.
If you want to pass complex data structures, use the L<Storable> module,
which is now standard with Perl 5.8.0.

This also means that only C<IPC::Door::Server> servers can talk to
non-C<IPC::Door::client> clients, and conversely.

Furthermore, if you have too much data (8KB or so) through the door, the
door server process dumps core with segmentation fault when DESTROY'd.

=item 2.  Some C<door_*> routines not implemented

Some door library routines
C<door_bind>, C<door_revoke>, C<door_server_create>, and C<door_unbind>
still need to be implemented.
C<door_info> is only partially implemented.

=item 3.  Minimal error checking

There should be more robust error checking and more friendly error
messages throughout.

=item 4.  Limited testing

C<IPC::Door> has been tested on Solaris 8 (with Sun Workshop compiler)
and 9 (with gcc 3.3) (both on SPARC).

I need more testing on following configurations (both SPARC and x86):

=over 4

=item *

Solaris 9 with Sun ONE Studio compiler.

=item *

64-bit perl executable.

=item *

Threaded perl.

=back

Please let me know if you can help me test the module on these
configurations.

=item 5.  A little inconsistent XS code

I'm still a beginner at XS (some may argue also at Perl), so the code,
especially the XS portion, can be improved.
Any suggestions are welcome.

=item 6.  Unicode compatibility

I have not tested this module with UTF-8-encoded strings.
It may or may not work.

=back

=head1 SEE ALSO

L<IPC::Door::Client>, L<IPC::Door::Server>

door_bind(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3m?a=view>E<gt>,
door_call(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3n?a=view>E<gt>,
door_create(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3n?a=view>E<gt>,
door_cred(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3p?a=view>E<gt>,
door_info(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3q?a=view>E<gt>,
door_return(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3r?a=view>E<gt>,
door_revoke(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3s?a=view>E<gt>,
door_server_create(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3t?a=view>E<gt>,
door_unbind(3DOOR) E<lt>L<http://docs.sun.com/db/doc/817-0697/6mgfsdh3u?a=view>E<gt>,

I<UNIX Network Programming Volume 2: Interprocess Communications>
E<lt>L<"http://www.kohala.com/start/unpv22e/unpv22e.html">E<gt>

I<Solaris Internals: Core Kernel Architecture>
E<lt>http://www.solarisinternals.com"E<gt>

=head1 AUTHOR

ASARI Hirotsugu <asarih at cpan dot org>

L<http://www.asari.net/perl>

=head1 COPYRIGHT AND LICENSE

Copyright 2003, 2004 by ASARI Hirotsugu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
