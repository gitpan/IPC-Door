#!PERL -w
#$Id: benchmark.pl,v 1.13 2004/05/23 04:30:04 asari Exp $

# A benchmark script to compare IPC through FIFO and doors.
# Not exactly helpful for a couple of reasons.
# 1.  Doors don't seem to handle bursts in data coming in.
#     After some calls from timethese(), the door we create simply
#     disappears, and the benchmark is useless.
# 2.  Even then, I've seen the FIFO code giving zero time after a long
#     pause.

use strict;
use Benchmark qw[:all];

use blib;
use File::Basename;
use IPC::Door::Client;
use Fcntl;
use Errno qw( EAGAIN );

my ( $base, $path, $suffix ) = fileparse( $0, qr(\.[t|pl]) );
my $pipe_server = $path . "bench-pipe-server.pl";
my $pipe_server_pid;
my $door_server = $path . "bench-door-server.pl";
my $door_server_pid;
my $door    = $path . 'DOOR';
my $dclient = new IPC::Door::Client($door);

use constant int_max   => 2**16 - 1;
use constant precision => 0.005;

my $iteration = shift || 200;

my $read_pipe  = $path . "CLIENT_PIPE";
my $write_pipe = $path . "SERVER_PIPE";

my %errors = ( 'DOOR' => 0, 'PIPE' => 0 );
my %count  = ( 'DOOR' => 0, 'PIPE' => 0 );

# run benchmarks
&spawn_pipe_server();
&spawn_door_server();
print "Ready for benchmarks? ";
my $ans = <STDIN>;
if ( $ans =~ m/^[nN]/ ) {
    &cleanup;
    die "Benchmarking aborted.\n";
}

#timethis( $iteration, \&call_pipe_server, 'DOOR');
timethese(
    $iteration,
    {
        'DOOR' => \&call_door_server,
        'PIPE' => \&call_pipe_server,
    }
);

print "DOOR: executed $count{'DOOR'}; $errors{'DOOR'} errors\n";
print "PIPE: executed $count{'PIPE'}; $errors{'PIPE'} errors\n";

&cleanup;

# Subroutines
sub spawn_pipe_server () {
  FORK_PIPE_SERVER: {
        if ( $pipe_server_pid = fork ) {
            ;
        }
        elsif ( defined $pipe_server_pid ) {
            exec $pipe_server;
        }
        elsif ( $! == EAGAIN ) {
            sleep 5;
            redo FORK_PIPE_SERVER;
        }
        else {
            die "Cannot fork the pipe server: $!\n";
        }
    }

}

sub spawn_door_server () {
  FORK_DOOR_SERVER: {
        if ( $door_server_pid = fork ) {
            ;
        }
        elsif ( defined $door_server_pid ) {
            exec $door_server;
        }
        elsif ( $! == EAGAIN ) {
            sleep 5;
            redo FORK_DOOR_SERVER;
        }
        else {
            die "Cannot fork the door server: $!\n";
        }
    }

}

sub call_door_server {
    my $num    = rand() * int_max;
    my $answer = $dclient->call($num);

    if ( abs( $answer - $num**2 ) > precision ) { $errors{'DOOR'}++ }
    $count{'DOOR'}++;
}

sub call_pipe_server {
    my $num = rand() * int_max;
    sysopen( SERVER_PIPE, $write_pipe, O_WRONLY )
      or die "Can't write to $write_pipe: $!";
    sysopen( CLIENT_PIPE, $read_pipe, O_RDONLY )
      or die "Can't read to $read_pipe: $!";

    print SERVER_PIPE $num;
    close SERVER_PIPE;

    my $answer = <CLIENT_PIPE>;
    close CLIENT_PIPE;

    if ( abs( $answer - $num**2 ) > precision ) { $errors{'PIPE'}++ }
    $count{'PIPE'}++;

    #	print "PIPE: Sent $num, got $answer\n";
}

sub cleanup {

    # terminate server processes
    kill 'INT', $door_server_pid;
    kill 'INT', $pipe_server_pid;

    unlink $door       || warn "Can't remove $door: $!\n";
    unlink $read_pipe  || warn "Can't remove $read_pipe: $!\n";
    unlink $write_pipe || warn "Can't remove $read_pipe: $!\n";
}
