#########################
# Test script for IPC::Door
# $Id: 09-client-server2.t,v 1.4 2004/05/01 07:59:59 asari Exp $

use Test::More tests => 1;
use strict;
use Fcntl;

#BEGIN { use_ok ('IPC::Door::Client') }
#BEGIN { use_ok ('IPC::Door::Server') }
use IPC::Door::Client;
use IPC::Door::Server;

use File::Basename;
use Devel::Peek;
use Fcntl;
use Errno qw( EAGAIN );

my ($base, $path, $suffix) = fileparse($0, qr(\.[t|pl]));
my $dserver_pid;
my $dserver_script = $path . "door-server2.pl";
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

my $str = "2004_01_01";
my $ans;
if ($dclient->is_door) {
    print "Sending $str: \n";
    $ans = $dclient->call($str, O_RDWR);
}
else {
    die "$door is not a door: $!\n";
}

$ans = '' unless defined($ans);
is($ans, "2004-01-01", "client-server2");

select undef, undef, undef, 2;
kill "TERM", $dserver_pid;
