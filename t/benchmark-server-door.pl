#!/usr/bin/perl -w

use strict;
use IPC::Door;
use Cwd;
use Fcntl;


my $door = shift;
$door .= '/DOOR' if (defined($door) && -d $door);

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

	select (undef, undef, undef, 0.2);

}
