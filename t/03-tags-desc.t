#########################
# Test script for IPC::Door
# $Date: 2003/09/03 02:17:28 $
# $Id: 03-tags-desc.t,v 1.1 2003/09/03 02:17:28 asari Exp $

# make sure the tags work

use Test::More tests => 3;
use Fcntl;
use strict;
BEGIN { use_ok('IPC::Door', qw(:desc)) };

is(DOOR_INVAL, -1, 'DOOR_INVAL');
is(DOOR_QUERY, -2, 'DOOR_QUERY');


# done
