# Makefile.PL for IPC::Door
# $Date: 2003/08/29 04:38:57 $
# $Id: Makefile.PL,v 1.3 2003/08/29 04:38:57 asari Exp $
use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
use POSIX qw[ uname ];
my ($sysname, $release) = (POSIX::uname())[0,2];
die "This module requires Solaris 2.6 and later.\n"
	unless $sysname eq 'SunOS' && $release >= 5.6;

WriteMakefile(
    'NAME'		=> 'IPC::Door',
    'VERSION_FROM'	=> 'Door.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Door.pm', # retrieve abstract from module
       AUTHOR     => 'ASARI Hirotsugu <hiro at asari dot net') : ()),
    'LIBS'		=> ['-ldoor -lthread'], # e.g., '-lm'
    'DEFINE'		=> '', # '-DDEBUGME' if debugging
    'INC'		=> '-I.', # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # 'OBJECT'		=> '$(O_FILES)', # link all the C files too
);
