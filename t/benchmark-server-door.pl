#!/usr/bin/perl -w

use strict;
use IPC::Door::Server;
use Cwd;
use Fcntl;

$SIG{INT}  = \&term;
$SIG{TERM} = \&term;

my $door = 'DOOR';

sub serv {
	my $arg = shift;

	return $arg**2;
}


my $server = new IPC::Door::Server($door, \&serv)
	|| die "Cannot create $door: $!\n";

while (1) {
	die "$door disappeared\n" unless $server->is_door;

	sysopen (DOOR, $door, O_WRONLY) or die "Can't open $door: $!\n";

	close DOOR;

}

sub term {
	my $sig = shift;
	print STDERR "$0: Caught signal $sig.\n" && die;
}
