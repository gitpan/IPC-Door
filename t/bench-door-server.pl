#!PERL -w
#$Id: bench-door-server.pl,v 1.7 2004/05/23 04:30:04 asari Exp $

use strict;
use File::Basename;
use Cwd;
use Fcntl;
use blib;
use IPC::Door::Server;

$SIG{INT}  = \&term;
$SIG{TERM} = \&term;

my ( $base, $path, $suffix ) = fileparse( $0, qr(\.[t|pl]) );
my $door = $path . 'DOOR';

sub serv {
    my $arg = shift;

    return $arg**2;
}

my $server = new IPC::Door::Server( $door, \&serv )
  || die "Cannot create $door: $!\n";

while (1) {
    die "$door disappeared\n" unless $server->is_door;

    sysopen( DOOR, $door, O_WRONLY ) or die "Can't open $door: $!\n";

    close DOOR;

    select undef, undef, undef, 0.2;

}

sub term {
    my $sig = shift;
    print STDERR "$0: Caught signal $sig.\n" && die;
}
