#########################
# Test script for IPC::Door
# $Date: 2003/09/04 03:40:34 $
# $Id: 07-main.t,v 1.2 2003/09/04 03:40:34 asari Exp $

use Test::More tests => 9;
use Fcntl;
use strict;
use constant INT_MAX=>2**16-1;
BEGIN { use_ok('IPC::Door::Client') }
BEGIN { use_ok('IPC::Door::Server') }


#########################

sub newserv ($);

sub newserv ($) {
	my $arg = shift;
	our ($DOOR_CLIENT_EUID, $DOOR_CLIENT_EGID, $DOOR_CLIENT_RUID,
	$DOOR_CLIENT_RGID, $DOOR_CLIENT_PID);

	ok( $> == $DOOR_CLIENT_EUID && $) == $DOOR_CLIENT_EGID && $< ==
$DOOR_CLIENT_RUID && $( == $DOOR_CLIENT_RGID && $DOOR_CLIENT_PID == $$, 'door_cred()' );

	return sqrt( $arg );
}

# Can I create a door?
my $dpath = 'DOOR';
if ( -e $dpath && !(-d $dpath) )
{
	unlink ($dpath) || die "Cannot delete $dpath: $!\n"
}
elsif ( -d $dpath )
{
	die "$dpath is a directory.  Cannot continue.\n";
}

my $dserver = new IPC::Door::Server($dpath, \&newserv);
ok( defined($dserver), 'door_create()' );
ok( $dserver->is_door, 'is_door, OO-version' );
ok( IPC::Door::is_door($dpath), 'is_door, subroutine version' );

# Can I open it?
#ok( sysopen(DOOR, $dpath, O_WRONLY), 'Open door' );

my ($dserver_pid, $dpath_attr, $dpath_uniq) = $dserver->info();
is( $dserver_pid, $$, 'info, OO-version' );
my ($dserver_pid, $dpath_attr, $dpath_uniq) = IPC::Door::info($dpath);
is( $dserver_pid, $$, 'info, subroutine version' );

my $dclient = new IPC::Door::Client($dpath);

# Can the client talk to server through the door?
my $num=INT_MAX*rand();	# some arbitrary number
my $delta=0.0005;	# precision

cmp_ok( abs($dclient->call($num, O_RDWR) - sqrt($num) ), '<=', $delta, 'door_call()' );

close(DOOR);
unlink ($dpath) || warn "Cannot delete $dpath: $!\n";
