/*
$Date: 2003/09/04 03:39:12 $
$Id: Door.xs,v 1.21 2003/09/04 03:39:12 asari Exp $
*/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <stdio.h>
#include <stropts.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <door.h>

#include "const-c.inc"

#define FILE_MODE (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)

// Debugging code (taken from Storable module)
#ifdef DEBUGME
#define TRACEME(x) STMT_START { \
	if (SvTRUE(perl_get_sv("IPC::Door::DEBUGME", TRUE))) \
		{ PerlIO_stdoutf x; PerlIO_stdoutf("\n"); } \
} STMT_END
#else
#define TRACEME(x)
#endif

/* The server process */
void servproc(void *cookie, char *dataptr, size_t datasize,
	door_desc_t *descptr, size_t ndesc)
{
	
	dSP;
	double arg = *((double *) dataptr);
	double result;
	door_cred_t info;
	SV * sv_callback; /* code reference */
	SV * sv;
	int count;	/* number of elements returned from Perl's &main::serv */

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVnv(arg)));
	
	PUTBACK;

	sv_callback = sv_2mortal((SV *) cookie);
	
	/* grab the client's credentials before calling &main::serv */
	if (door_cred(&info) < 0) {
		TRACEME(("door_cred() failed!"));
			PerlIO_printf(PerlIO_stderr(), "door_cred() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
	}

	/* make client's credentials available inside perl */
	sv = get_sv("main::DOOR_CLIENT_EUID", TRUE);
	sv_setiv(sv, info.dc_euid);
	sv = get_sv("main::DOOR_CLIENT_EGID", TRUE);
	sv_setiv(sv, info.dc_egid);
	sv = get_sv("main::DOOR_CLIENT_RUID", TRUE);
	sv_setiv(sv, info.dc_ruid);
	sv = get_sv("main::DOOR_CLIENT_RGID", TRUE);
	sv_setiv(sv, info.dc_rgid);
	sv = get_sv("main::DOOR_CLIENT_PID", TRUE);
	sv_setiv(sv, info.dc_pid);


	count = call_sv(sv_callback, G_SCALAR);

	SPAGAIN;
	
	if (count != 1)
		croak ("Big, big trouble\n");
	result = POPn;
	
	if (door_return((char *) &result, sizeof(result),NULL,0) < 0) {
			TRACEME(("door_return() failed!"));
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_return() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
		} else {
			/* fall through */
			TRACEME(("door_return() succeeded!"));
		}

	PUTBACK;
	

	FREETMPS;
	LEAVE;

}

/*
Start XSUB
*/

MODULE=IPC::Door	PACKAGE=IPC::Door

INCLUDE: const-xs.inc

void
__info(sv_path)
	SV * sv_path
PREINIT:
	char * path = SvPV(sv_path, PL_na);
	int fd;
	struct stat stat;
	door_info_t info;
	SV * sv;
PPCODE:
	if ((fd = open(path, O_RDONLY)) < 0) {
		croak ("open() failed\n");
		XSRETURN_UNDEF;
	}
	if (fstat(fd, &stat) < 0) {
		croak ("fstat() failed\n");
		XSRETURN_UNDEF;
	}
	if (S_ISDOOR(stat.st_mode) == 0) {
		PerlIO_printf(PerlIO_stderr(), "%s is not a door\n", path);
		XSRETURN_UNDEF;
	}
	/* path is a door, so gather info */
	if (door_info(fd, &info) < 0) {
		PerlIO_printf(PerlIO_stderr(), "door_info() failed\n");
	} else {
		XPUSHs(sv_2mortal(newSViv((long) info.di_target)));
		XPUSHs(sv_2mortal(newSViv((long) info.di_attributes)));
		XPUSHs(sv_2mortal(newSViv((long) info.di_uniquifier)));
	}

	if (close(fd) < 0) croak("close() failed\n");



MODULE=IPC::Door	PACKAGE=IPC::Door::Server
int
__create(sv_class, sv_path, sv_callback)
	SV *sv_class
	SV *sv_path
	SV *sv_callback
	PROTOTYPE: $$$
	CODE:
		char *class = SvPV(sv_class, PL_na);
		int fd;
		char *path = SvPV(sv_path, PL_na);
		char *callback = SvPV(sv_callback, PL_na);

		/* Make sure that sv_callback is sane */
		if (!SvROK(sv_callback) || (SvTYPE(SvRV(sv_callback)) != SVt_PVCV)) {
			PerlIO_printf(PerlIO_stderr(), "%s is not a code reference.\n", callback);
			XSRETURN_UNDEF;
		}

		/*
		   Since we need sv_callback in servproc, which is out of scope of
		   this function, we have to increase its reference count so that
		   perl does not free the memory.
		   NOTE: we make the cookie mortal in servproc.
		*/
		SvREFCNT_inc(sv_callback);

		if ((fd = door_create(servproc, sv_callback, 0)) < 0) {
			TRACEME(("door_create() failed!"));
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_create() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
			if (close(fd) < 0) croak("close() failed\n");
			XSRETURN_UNDEF;
		} else {
			TRACEME(("door_create() succeeded!"));
			/* need to trap potential errors here */
			close(open(path, O_CREAT | O_RDWR, FILE_MODE));
			RETVAL = fattach(fd, path);
		}
	OUTPUT:
		RETVAL


MODULE=IPC::Door	PACKAGE=IPC::Door::Client
double
__call(sv_class, sv_path, sv_input, sv_attr)
	SV * sv_class
	SV * sv_path
	SV * sv_input
	SV * sv_attr
	CODE:
		char *class  = SvPV(sv_class, PL_na);
		char *path   = SvPV(sv_path, PL_na);
		double input = SvNV(sv_input);
		int attr     = SvIV(sv_attr);
		int fd;
		door_arg_t arg;
		double output;

		if ((fd = open(path, attr)) < 0) {
			TRACEME(("open() failed on the door\n"));
			PerlIO_printf(PerlIO_stderr(), "open() failed\n");
			XSRETURN_UNDEF;
		};


		arg.data_ptr = (char *) &input;
		arg.data_size = sizeof(double);
		arg.desc_ptr = NULL;
		arg.desc_num = 0;
		arg.rbuf = (char *) &output;
		arg.rsize = sizeof(double);

		if (door_call(fd, &arg) < 0) {
			TRACEME(("door_call() failed!"));
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_call() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
			if (close(fd) < 0) croak ("close() failed\n");
			XSRETURN_UNDEF;
		} else {
			TRACEME(("door_call() succeeded!"));
			if (close(fd) < 0) croak ("close() failed\n");
			RETVAL = output;
		}

	OUTPUT:
		RETVAL

