#########################
# Test script for IPC::Door
# $Date: 2003/09/03 02:17:28 $
# $Id: 04-tags-errors.t,v 1.1 2003/09/03 02:17:28 asari Exp $

# make sure the tags work

use Test::More tests => 3;
use Fcntl;
use strict;
BEGIN { use_ok('IPC::Door', qw(:errors)) }

# these are optional ( #if defined(_KERNEL) )
SKIP: {
	eval { DOOR_WAIT };
	skip 'DOOR_WAIT', 1 if $@;
	is(DOOR_WAIT, -1, 'DOOR_WAIT');
}
SKIP: {
	eval { DOOR_EXIT };
	skip 'DOOR_EXIT', 1 if $@;
	is(DOOR_EXIT, -2, 'DOOR_EXIT');
}


# done
