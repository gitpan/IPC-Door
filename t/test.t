#########################
# Test script for IPC::Door
# $Date: 2003/08/29 04:39:00 $
# $Id: test.t,v 1.9 2003/08/29 04:39:00 asari Exp $

use Test::More tests => 4;
use Fcntl;
use strict;
use constant INT_MAX=>2**16-1;
BEGIN { use_ok('IPC::Door') };

my $debugging = 0;	# useful only if -DDEBUGME is defined in Makefile.PL
#########################

sub serv ($);

# an example of &main::serv
sub serv ($) {
	my $arg = shift;
	return sqrt( $arg );
}

# Can I create a door?
my $dpath = 'TEST';
if ( -e $dpath && !(-d $dpath) )
{
	unlink ($dpath) || die "Cannot delete $dpath: $!\n"
}
elsif ( -d $dpath )
{
	die "$dpath is a directory.  Cannot continue.\n";
}

my $dserver = new IPC::Door::Server ($dpath, \&serv);
ok( $dserver->is_door, 'Create door' );

# Can I open it?
ok( sysopen(DOOR, $dpath, O_WRONLY), 'Open door' );

my $dclient = new IPC::Door::Client ($dpath);

# Can the client talk to server through the door?
my $num=INT_MAX*rand();	# some arbitrary number
my $delta=0.0005;	# precision
if ($debugging) {
	require Devel::Peek;
	$IPC::Door::DEBUGME=1;
	Devel::Peek::Dump($dclient->call($num));
	$IPC::Door::DEBUGME=0;
}
cmp_ok( abs($dclient->call( $num ) - serv($num) ), '<=', $delta, "Square root" );

close(DOOR);
unlink ($dpath) || warn "Cannot delete $dpath: $!\n";

# $Log: test.t,v $
# Revision 1.9  2003/08/29 04:39:00  asari
# Update for the first public release, version 0.02
#
# Revision 1.8  2003/08/28 03:50:37  asari
# &main::serv is now embedded in servproc, so that certain functions can
# be defined by the script.
#
# Revision 1.7  2003/08/27 12:19:58  asari
# A more random testing
#
# Revision 1.6  2003/08/27 05:50:24  asari
# Varias benchmark scripts.
#
# Revision 1.5  2003/08/26 01:42:34  asari
# Split Solaris::IPC::Door into Solaris::IPC::Door::Server and Solaris::IPC::Door::Client.
#
