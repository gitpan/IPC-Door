#!/usr/local/bin/perl -w
#$Date: 2003/08/29 04:39:00 $
#$Id: benchmark-server-pipe.pl,v 1.3 2003/08/29 04:39:00 asari Exp $
use strict;
use Fcntl;

# read STDIN and write its square to STDOUT


my $read_pipe = shift;
my $write_pipe = $read_pipe;
$read_pipe .= '/SERVER_PIPE' if (defined($read_pipe) && -d $read_pipe);
$write_pipe .= '/CLIENT_PIPE' if (defined($write_pipe) && -d $write_pipe);

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
