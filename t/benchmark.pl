#!/usr/local/bin/perl
#$Date: 2003/09/02 13:21:38 $
#$Id: benchmark.pl,v 1.5 2003/09/02 13:21:38 asari Exp $

use warnings;
use strict;
use IPC::Door::Client;
use Fcntl;
use Benchmark;
use Errno qw[ EAGAIN ];

use constant int_max => 2**16-1;
use constant precision => 0.005;

my $iteration = shift || 1500;

my $door = "DOOR";
my $read_pipe = "CLIENT_PIPE";
my $write_pipe = "SERVER_PIPE";

my $dserver_script = "benchmark-server-door.pl";
my $pserver_script = "benchmark-server-pipe.pl";
my $dclient = new IPC::Door::Client ($door);

my %errors = ( 'DOOR'=>0, 'PIPE'=>0 );
my %count  = ( 'DOOR'=>0, 'PIPE'=>0 );

my ($dserver_pid, $pserver_pid);

########################################
# start server processes
########################################
FORK_DOOR_SERVER: {
	if ($dserver_pid = fork) {
		# fall through
		;
	} elsif (defined $dserver_pid) {
		 exec $dserver_script;
	} elsif ($! == EAGAIN) {
		 sleep 5;
		 redo FORK_DOOR_SERVER;
	} else {
		 die "Cannot fork the door server: $!\n";
	}
}

FORK_PIPE_SERVER: {
	if ($pserver_pid = fork) {
		# fall through
		;
	} elsif (defined $pserver_pid) {
		 exec $pserver_script;
	} elsif ($! == EAGAIN) {
		 sleep 5;
		 redo FORK_PIPE_SERVER;
	} else {
		 die "Cannot fork the pipe server: $!\n";
	}
}


# run benchmarks
print "Ready for benchmarks?";
my $ans = <STDIN>;
if ($ans =~ m/^[nN]/) {
	&cleanup;
	die "Benchmarking aborted.\n";
};

#timethis( $iteration, \&call_pipe_server, 'DOOR');
timethese( $iteration, {
			'DOOR' => \&call_door_server,
			'PIPE' => \&call_pipe_server
	 } );


print "DOOR: executed $count{'DOOR'}; errors $errors{'DOOR'}\n";
print "PIPE: executed $count{'PIPE'}; errors $errors{'PIPE'}\n";

&cleanup;

#
# subroutines
#

##################################################
# Door client
##################################################


sub call_door_server {
	my $num = rand()*int_max;
	my $answer = $dclient->call($num);

	if (abs($answer - $num**2) > precision) { $errors{'DOOR'}++ };
	$count{'DOOR'}++;


}

##################################################
# pipe client
##################################################
sub call_pipe_server {
	my $num = rand()*int_max;
	sysopen ( SERVER_PIPE, $write_pipe, O_WRONLY )
		or die "Can't write to $write_pipe: $!";
	sysopen ( CLIENT_PIPE, $read_pipe, O_RDONLY )
		or die "Can't read to $read_pipe: $!";

	print SERVER_PIPE $num;
	close SERVER_PIPE;

	my $answer = <CLIENT_PIPE>;
	close CLIENT_PIPE;

	if (abs($answer - $num**2) > precision) { $errors{'PIPE'}++ };
	$count{'PIPE'}++;
#	print "PIPE: Sent $num, got $answer\n";

}

sub cleanup {
	# terminate server processes
	kill 'INT', $dserver_pid;
	kill 'INT', $pserver_pid;

	unlink $door       || warn "Can't remove $door: $!\n";
	unlink $read_pipe  || warn "Can't remove $read_pipe: $!\n";
	unlink $write_pipe || warn "Can't remove $read_pipe: $!\n";
}
