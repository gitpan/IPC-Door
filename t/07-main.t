#########################
# Test script for IPC::Door
# $Id: 07-main.t,v 1.8 2004/05/23 04:14:30 asari Exp $

use Test::More tests => 9;
use Fcntl;
use strict;
use constant INT_MAX => 2**16 - 1;
use IPC::Door qw(:attr);
BEGIN { use_ok('IPC::Door::Client') }
BEGIN { use_ok('IPC::Door::Server') }

#########################

sub srv ($);

sub srv ($) {
    my $arg = shift;
    our (
        $DOOR_CLIENT_EUID, $DOOR_CLIENT_EGID, $DOOR_CLIENT_RUID,
        $DOOR_CLIENT_RGID, $DOOR_CLIENT_PID
    );

    ok(
        $> == $DOOR_CLIENT_EUID
          && $) == $DOOR_CLIENT_EGID
          && $< == $DOOR_CLIENT_RUID
          && $( == $DOOR_CLIENT_RGID
          && $$ == $DOOR_CLIENT_PID,
        'door_cred()'
    );

    my $ans = sqrt($arg);
    return $ans;
}

# Can I create a door?
my $dpath = 'DOOR';
if (-e $dpath && !(-d $dpath)) {
    unlink($dpath) || die "Cannot delete $dpath: $!\n";
}
elsif (-d $dpath) {
    die "$dpath is a directory.  Cannot continue.\n";
}

my $dserver = new IPC::Door::Server($dpath, \&srv, DOOR_UNREF);
ok(defined($dserver),          'door_create()');
ok($dserver->is_door,          'is_door, OO-version');
ok(IPC::Door::is_door($dpath), 'is_door, subroutine version');

# Test door_info()
my ($dserver_pid, $dpath_attr, $dpath_uniq) = $dserver->info();
is($dserver_pid, $$, 'info (pid), OO-version');

#is(($dpath_attr & DOOR_UNREF), DOOR_UNREF, 'info (DOOR_UNREF attribute), OO-version');

($dserver_pid, $dpath_attr, $dpath_uniq) = IPC::Door::info($dpath);
is($dserver_pid, $$, 'info (pid), subroutine version');

#is(($dpath_attr & DOOR_UNREF), DOOR_UNREF, 'info (DOOR_UNREF attribute), subroutine version');

my $dclient = new IPC::Door::Client($dpath);

# Can the client talk to server through the door?
my $num   = INT_MAX * rand();    # some arbitrary number
my $delta = 0.0005;              # precision

#print Data::Dumper::Dumper(my $ans = $dclient->call(\$num,O_RDWR)),"\n";
my $ans = $dclient->call($num, O_RDWR);

cmp_ok(abs($ans - sqrt($num)), '<=', $delta, 'door_call()');

#close(DOOR);
#unlink($dpath) || warn "Cannot delete $dpath: $!\n";
