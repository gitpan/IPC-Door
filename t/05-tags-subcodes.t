#########################
# Test script for IPC::Door
# $Id: 05-tags-subcodes.t,v 1.5 2004/05/01 07:59:59 asari Exp $

# make sure the tags work

use Test::More tests => 10;
use Fcntl;
use strict;
use POSIX qw( uname );
BEGIN { use_ok('IPC::Door', qw(:subcodes)) }

# don't skip these
is(DOOR_CREATE, 0, 'DOOR_CREATE');
is(DOOR_REVOKE, 1, 'DOOR_REVOKE');
is(DOOR_INFO,   2, 'DOOR_INFO');
is(DOOR_CALL,   3, 'DOOR_CALL');
is(DOOR_RETURN, 4, 'DOOR_RETURN');
is(DOOR_CRED,   5, 'DOOR_CRED');
is(DOOR_BIND,   6, 'DOOR_BIND');
is(DOOR_UNBIND, 7, 'DOOR_UNBIND');

# DOOR_UNREFSYS is new in Solaris 9
SKIP: {
    my $release = (POSIX::uname())[2];
    skip "DOOR_UNREFSYS is not defined SunOS $release", 1 if $release < 5.9;
    is(DOOR_UNREFSYS, 8, 'DOOR_UNREFSYS');
}

# done
