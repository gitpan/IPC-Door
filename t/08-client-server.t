#########################
# Test script for IPC::Door
# $Id: 08-client-server.t,v 1.6 2004/05/06 03:02:13 asari Exp $

use Test::More tests => 1;
use strict;
use Fcntl;

#BEGIN { use_ok ('IPC::Door::Client') }
#BEGIN { use_ok ('IPC::Door::Server') }
use IPC::Door::Client;
#use IPC::Door::Server;

use File::Basename;
use Devel::Peek;
use Fcntl;
use Errno qw( EAGAIN );

my ($base, $path, $suffix) = fileparse($0, qr(\.[t|pl]$));
my $dserver_pid;
my $dserver_script = $path . "door-server.pl";
my $door           = $path . 'DOOR';

FORK_DOOR_SERVER: {
    if ($dserver_pid = fork) {

        # fall through
        ;
    }
    elsif (defined $dserver_pid) {
        exec $dserver_script;
    }
    elsif ($! == EAGAIN) {
        sleep 5;
        redo FORK_DOOR_SERVER;
    }
    else {
        die "Cannot fork the door server: $!\n";
    }
}

#ok(defined $dserver_pid, 'door server fork & exec');

my $dclient = new IPC::Door::Client($door);

# sleep a little while to make sure that the door server has been forked
select undef, undef, undef, 2;

my $num = rand() * (2**16 - 1);
my $ans;
if ($dclient->is_door) {
#    print "Sending $num: \n";
    $ans = $dclient->call($num, O_RDWR);
}
else {
    die "$door is not a door: $!\n";
}

my $precision = 0.0005;

#TODO: {
#	local $TODO = "door_call fails when talking to a different process";
$ans = 0 unless defined($ans);
cmp_ok(abs($ans - $num**2), '<=', $precision, 'client call');

#	unlink $door or die "Cannot remove $door: $?\n";
#}

select undef, undef, undef, 2;
kill "TERM", $dserver_pid;
