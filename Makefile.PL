# Makefile.PL for IPC::Door
# $Id: Makefile.PL,v 1.15 2004/05/19 13:11:32 asari Exp $
use 5.006;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
use POSIX qw[ uname ];
my ($sysname, $release) = (POSIX::uname())[ 0, 2 ];
my ($major, $minor) = split /\./,$release;
die "This module requires Solaris 2.6 and later.\n"
  unless $sysname eq 'SunOS' && $major >= 5 && $minor >= 6;

my $ldflags = '-D_REENTRANT'.($minor >= 10? ' -DHAS_UCRED_H': '');

######################################################
# Edit the shebang lines in the server scripts
######################################################
if (eval { require Tie::File }) {
    my $mm = {};
    bless($mm, 'ExtUtils::MM_Unix');
    my @path = split ':', $ENV{'PATH'};
    my $fullperl  = $mm->find_perl(5.006, [ 'perl', 'perl5' ], \@path);
    my $scriptdir = 't';

    opendir TESTDIR, $scriptdir;
    my @scripts = grep { /\.pl$/ } readdir TESTDIR;

    my @lines;
    foreach my $script (@scripts) {
        tie(@lines, 'Tie::File', "$scriptdir/$script")
          || warn "Cannot open $script: $!\n";
        $lines[0] =~ s/PERL/$fullperl/g;
        untie @lines;
    }
    closedir TESTDIR;
}
else {
    warn <<WARNING;
You do not have Tie::File installed.  Before you run "make test", please
edit "t/*.pl" files so that appropriate perl interpreter is called.
WARNING
}

#######################################################
# Write Makefile
#######################################################
WriteMakefile(
    'NAME'         => 'IPC::Door',
    'VERSION_FROM' => 'Door.pm',     # finds $VERSION
    'PREREQ_PM'    => {},            # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => 'Door.pm',    # retrieve abstract from module
            AUTHOR => 'ASARI Hirotsugu <hiro at asari dot net'
          )
        : ()
    ),
    'LIBS'   => ['-ldoor -lthread'],       # e.g., '-lm'
    'DEFINE' => $ldflags,            # '-DDEBUGME' if debugging
    'INC'    => '-I.',                     # e.g., '-I. -I/usr/include/other'
         # Undo the shebang line edits for distribution
    dist => {
        PREOP =>
'$(PERLRUN) -pi -e \'s/^\#!.*/\#!PERL -w/\' $(DISTVNAME)/t/*.pl; cd $(DISTVNAME); cpansign -s',
    },
    clean => { FILES => 'const-c.inc const-xs.inc' },
);
if (eval { require ExtUtils::Constant; 1 }) {

    # If you edit these definitions to change the constants used by this module,
    # you will need to use the generated const-c.inc and const-xs.inc
    # files to replace their "fallback" counterparts before distributing your
    # changes.
    my @names = (
        qw(DOOR_ATTR_MASK DOOR_BIND DOOR_CALL DOOR_CREATE
          DOOR_DELAY DOOR_DESCRIPTOR DOOR_EXIT DOOR_HANDLE DOOR_INFO
          DOOR_INVAL DOOR_IS_UNREF DOOR_LOCAL DOOR_PRIVATE DOOR_QUERY
          DOOR_RELEASE DOOR_RETURN DOOR_REVOKE DOOR_REVOKED DOOR_UNBIND
          DOOR_UNREF DOOR_UNREFSYS DOOR_UNREF_ACTIVE
          DOOR_UNREF_MULTI DOOR_WAIT S_IFDOOR)
    );
    # For Solaris 10, Sun replaced DOOR_CRED with DOOR_UCRED
    push @names, ($minor >= 10? 'DOOR_UCRED': 'DOOR_CRED');
    if ($minor >= 10) { push @names,
        # These macros are new in Solaris 10
        'DOOR_REFUSE_DESC','DOOR_CREATE_MASK','DOOR_KI_CREATE_MASK' };
    ExtUtils::Constant::WriteConstants(
        NAME         => 'IPC::Door',
        NAMES        => \@names,
        DEFAULT_TYPE => 'IV',
        C_FILE       => 'const-c.inc',
        XS_FILE      => 'const-xs.inc',
    );

}
else {
    use File::Copy;
    use File::Spec;
    my @const = ($minor >= 10)?
        qw/const-c.inc_10 const-xs.inc_10/: qw/const-c.inc const-xs.inc/;
    foreach my $file ( @const ) {
        my $fallback = File::Spec->catfile('fallback', $file);
        copy($fallback, $file) or die "Can't copy $fallback to $file: $!";
    }
}
