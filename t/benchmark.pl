#!/usr/bin/perl -w
#$Date: 2003/08/29 04:39:00 $
#$Id: benchmark.pl,v 1.4 2003/08/29 04:39:00 asari Exp $

use strict;
use IPC::Door;
use Fcntl;
use Benchmark;

use constant int_max => 2**16-1;
use constant precision => 0.005;

my $iteration = shift || 1500;

my $prefix=$0;
$prefix =~ s{[^/]*$}{};	# delete the file name from $0
my $door = $prefix . '/DOOR';
my $read_pipe = $prefix .'/CLIENT_PIPE';
my $write_pipe = $prefix .'/SERVER_PIPE';

my $dserver_script = $prefix . 'benchmark-server-door.pl';
my $pserver_script = $prefix . 'benchmark-pipe-door.pl';

my %errors = ( 'DOOR'=>0, 'PIPE'=>0 );
my %count;



# start a server through a pipe


# run benchmarks

##################################################
# Door client
##################################################

my $dclient = new IPC::Door::Client ($door);

sub call_door_server {
	my $num = rand()*int_max;
	my $answer = $dclient->call($num);

	if (abs($answer - $num**2) > precision) { $errors{'DOOR'}++ };
	$count{'DOOR'}++;

#	print "DOOR: Sent $num, got $answer\n";

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

#timethis( $iteration, \&call_pipe_server, 'DOOR');
timethese( $iteration, {
			'DOOR' => \&call_door_server,
			'PIPE' => \&call_pipe_server
	 } );


# kill the servers

# remove the pipes and the door

print "DOOR: executed $count{'DOOR'}; errors $errors{'DOOR'}\n";
print "PIPE: executed $count{'PIPE'}; errors $errors{'PIPE'}\n";

unlink $door || warn "Can't remove $door: $!\n";
unlink $read_pipe || warn "Can't remove $read_pipe: $!\n";
unlink $write_pipe || warn "Can't remove $read_pipe: $!\n";
