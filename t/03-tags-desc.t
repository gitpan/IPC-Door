#########################
# Test script for IPC::Door
# $Id: 03-tags-desc.t,v 1.3 2004/05/01 07:59:58 asari Exp $

# make sure the tags work

use Test::More tests => 3;
use Fcntl;
use strict;
BEGIN { use_ok('IPC::Door', qw(:desc)) }

is(DOOR_INVAL, -1, 'DOOR_INVAL');
is(DOOR_QUERY, -2, 'DOOR_QUERY');

# done
