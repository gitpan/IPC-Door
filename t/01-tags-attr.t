#########################
# Test script for IPC::Door
# $Id: 01-tags-attr.t,v 1.4 2004/05/01 07:59:58 asari Exp $

# make sure the tags work

use Test::More tests => 10;
use Fcntl;
use strict;
BEGIN { use_ok('IPC::Door', qw(:attr)) }

# Don't skip these!
is(DOOR_ATTR_MASK,
    DOOR_UNREF | DOOR_PRIVATE | DOOR_UNREF_MULTI | DOOR_LOCAL | DOOR_REVOKED |
      DOOR_IS_UNREF,
    'DOOR_ATTR_MASK'
);
is(DOOR_UNREF,        0x01,     'DOOR_UNREF');
is(DOOR_PRIVATE,      0x02,     'DOOR_PRIVATE');
is(DOOR_UNREF_MULTI,  0x10,     'DOOR_UNREF_MULTI');
is(DOOR_LOCAL,        0x04,     'DOOR_LOCAL');
is(DOOR_REVOKED,      0x08,     'DOOR_REVOKED');
is(DOOR_IS_UNREF,     0x20,     'DOOR_IS_UNREF');
is(DOOR_DELAY,        0x80000,  'DOOR_DELAY');
is(DOOR_UNREF_ACTIVE, 0x100000, 'DOOR_UNREF_ACTIVE');

# done
