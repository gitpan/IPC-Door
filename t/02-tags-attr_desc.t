#########################
# Test script for IPC::Door
# $Date: 2003/09/03 02:17:28 $
# $Id: 02-tags-attr_desc.t,v 1.1 2003/09/03 02:17:28 asari Exp $

# make sure the tags work

use Test::More tests => 4;
use Fcntl;
use strict;
BEGIN { use_ok('IPC::Door', qw(:attr_desc)) }

is(DOOR_DESCRIPTOR, 0x10000, 'DOOR_DESCRIPTOR');

# this one is optional ( #ifdef _KERNEL )
SKIP: {
	eval { DOOR_HANDLE };
	skip 'DOOR_HANDLE', 1 if $@;
	is(DOOR_HANDLE, 0x20000, 'DOOR_HANDLE');
}

is(DOOR_RELEASE, 0x40000, 'DOOR_RELEASE');


# done
