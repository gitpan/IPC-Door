#!/usr/local/bin/perl -w
#$Date: 2003/09/02 13:21:38 $
#$Id: benchmark-server-pipe.pl,v 1.4 2003/09/02 13:21:38 asari Exp $
use strict;
use Fcntl;

$SIG{INT}  = \&term;
$SIG{TERM} = \&term;


my $read_pipe  = 'SERVER_PIPE';
my $write_pipe = 'CLIENT_PIPE';

unless (-p $write_pipe) {
	if (-e _) {
			die "$0: Won't overwrite $write_pipe\n";
	} else {
			require POSIX;
			POSIX::mkfifo( $write_pipe, 0666 ) or die "Can't create $write_pipe: $!\n";
	}
}

unless (-p $read_pipe) {
	if (-e _) {
			die "$0: Won't overwrite $read_pipe\n";
	} else {
			require POSIX;
			POSIX::mkfifo( $read_pipe, 0666 ) or die "Can't create $read_pipe: $!\n";
	}
}

while (1) {
	die "Pipe $read_pipe disappeared\n" unless -p $read_pipe;

	sysopen ( SERVER_PIPE, $read_pipe, O_RDONLY )
		or die "Can't write to $read_pipe: $!";
	sysopen ( CLIENT_PIPE, $write_pipe, O_WRONLY )
		or die "Can't read to $write_pipe: $!";

	my $arg = <SERVER_PIPE>;
	print CLIENT_PIPE $arg**2;

	close SERVER_PIPE;
	close CLIENT_PIPE;

}

sub term {
	my $sig = shift;
	die "$0: Caught signal $sig.\n";
}
