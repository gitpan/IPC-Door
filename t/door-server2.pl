#!PERL -w
# $Id: door-server2.pl,v 1.9 2004/05/23 04:30:04 asari Exp $

# this script will be forked and exec'd by 09-client-server2.t

use strict;
use Fcntl;
use Devel::Peek;
use Data::Dumper;
use blib;

use File::Basename;
my ( $base, $path, $suffix ) = fileparse( $0, qr(\.pl$) );

$SIG{INT}  = \&term;
$SIG{TERM} = \&term;

#$SIG{__WARN__} = \&term;

use IPC::Door::Server;
my $door = $path . 'DOOR';

check_door($door);

our $ok_to_die = 0;

my $server = new IPC::Door::Server( $door, \&serv )
  || die "Cannot create $door: $!\n";

#Dump($server);

while ( !($ok_to_die) ) {
    die "$door disappeared\n" unless IPC::Door::is_door($door);
    sysopen( DOOR, $door, O_WRONLY ) || die "Can't write to $door: $!\n";
    close DOOR;
    select undef, undef, undef, 0.2;
}

#####################################################
#
# subroutines
#
#####################################################
sub term {
    my $sig = shift;
    $ok_to_die = 1;
#    unlink $door || warn "Can't remove $door.\n";

    #	print STDERR "$0: Caught signal $sig.\n";
}

sub serv {
    my $arg = shift;
#    print "&serv's argument: $arg\n";

    $arg =~ s/_/-/g;

    return $arg;
}

sub check_door {
    my $door = shift;
    if ( IPC::Door::is_door($door) ) {
        die "$door is an existing door.  Terminating.\n";
    }
    elsif ( stat($door) ) {
        print
          "$door exists, but it is not a door.  Shall I unlink it?  [y/n]: ";
        my $reply = <STDIN>;
        chomp $reply;
        if ( $reply =~ m/^y/i ) {
            unlink $door || die "Can't remove $door: $!\n";
        }
        else {
            exit "OK, I leave $door alone.\n";
        }
    }
}
