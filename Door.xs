/*
$Id: Door.xs,v 1.35 2004/05/01 07:45:34 asari Exp $
*/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <stdio.h>
#include <stdlib.h>
#include <stropts.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <door.h>
#include <sys/ddi.h>

#include "const-c.inc"

#define FILE_MODE (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
#define MAX_STRING 512

/* typedefs */
typedef struct {
//	NV   ipc_door_data_nv;
	char ipc_door_data_pv[MAX_STRING];
//	bool want_num;  /* perl.h should have it */
} ipc_door_data_t;

/* The server process */
void servproc(void *cookie, char *dataptr, size_t datasize,
	door_desc_t *descptr, size_t ndesc)
{
	dSP;

	ipc_door_data_t arg, retval;
	SV          *result;
	door_cred_t info;
	SV          *sv_callback; /* code reference */
	SV          *sv; /* convenience variable */
	void        *tmp;
	char        *str;
	int         count;	/* number of elements returned from sv_callback in Perl */

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);

//	printf("datasize: %d, sizeof(arg): %d\n", datasize, sizeof(arg));
	memmove(&arg, dataptr, min(datasize,sizeof(arg)));
	if ((str = calloc(MAX_STRING, 1)) == NULL)
		return;
	arg.ipc_door_data_pv[MAX_STRING-1]='\0';
	strncpy(str, arg.ipc_door_data_pv, MAX_STRING);
//	memmove((void*)str, arg.ipc_door_data_pv, MAX_STRING);
//	printf("str: %x\narg.ipc_door_data_pv: %x\n", str, arg.ipc_door_data_pv);
	sv=sv_newmortal();
	sv_callback=sv_newmortal();
	sv_callback = (SV *) cookie;
	sv = newSVpv( str, 0 );
	free(str);
//	(void)SvUPGRADE(sv,SVt_PVNV);
//	SvIV(sv);
//	SvNV(sv);
//	printf("Now in servproc\n");
//	sv_dump(sv);

	if (SvOK(sv)) {
		XPUSHs(sv);
	} else {
		/* fall through; the argument is not an SV */
		PerlIO_printf(PerlIO_stderr(),"Coderef improperly defined\n");
		return;
	}

	PUTBACK;

	/* grab the client's credentials before calling &main::serv */
	if (door_cred(&info) < 0) {
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
		croak("servproc: Expected 1 value from server process; got %d values instead.\n", count);
	result = POPs;
	str = SvPV( result, PL_na );
	strncpy(retval.ipc_door_data_pv, str, MAX_STRING);

	/* what does result look like? */


	if (door_return((char *) &retval, sizeof(retval),NULL,0) < 0) {
//			printf("door_return() failed!");
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_return() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
//		} else {
			/* fall through */
//			printf("door_return() succeeded!");
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

int
is_door(sv)
	SV * sv
PREINIT:
	char * path;
	HV* hv;
	SV** svp;
	struct stat buf;
CODE:
	if (sv_isobject(sv) && sv_derived_from(sv, "IPC::Door")) {
		hv=(HV*)SvRV(sv);
		svp=hv_fetch( hv, "path", 4, FALSE);
		path=SvPV(*svp, PL_na);
	} else {
		path=SvPV(sv, PL_na);
	}
	if (stat(path, &buf) <0)
		XSRETURN_UNDEF;
	RETVAL=S_ISDOOR(buf.st_mode);
OUTPUT:
	RETVAL

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
		SV   *sv_server = SvRV(sv_class); /* IPC::Door::Server object */
		int  fd;
		char *path      = SvPV(sv_path, PL_na);
		char *callback  = SvPV(sv_callback, PL_na);
//		SV ** svp;

		/* Make sure sv_server is sane */
		if (!sv_isobject(sv_class)) {
			PerlIO_printf(PerlIO_stderr(), "Non-object passed in __create()\n");
			XSRETURN_UNDEF;
		}

		/* Make sure that sv_callback is sane */
		if (!SvROK(sv_callback) || (SvTYPE(SvRV(sv_callback)) != SVt_PVCV)) {
			PerlIO_printf(PerlIO_stderr(), "%s is not a code reference.\n", callback);
			XSRETURN_UNDEF;
		}

		/* set sv_callback */
		sv_callback = *(hv_fetch((HV *)sv_server, "callback", 8, FALSE));


		if ((fd = door_create(servproc, sv_callback, 0)) < 0) {
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_create() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
			if (close(fd) < 0) croak("close() failed\n");
			XSRETURN_UNDEF;
		} else {
			/* need to trap potential errors here */
			close(open(path, O_CREAT | O_RDWR, FILE_MODE));
			if ( (RETVAL=fattach(fd, path)) < 0) {
				PerlIO_printf(PerlIO_stderr(), "fattach() failed: ");
				PerlIO_printf(PerlIO_stderr(), strerror(errno));
				PerlIO_printf(PerlIO_stderr(), "\n");
				XSRETURN_UNDEF;
			}
		}

MODULE=IPC::Door	PACKAGE=IPC::Door::Client
SV *
__call(sv_class, sv_path, sv_input, sv_attr)
	SV * sv_class
	SV * sv_path
	SV * sv_input
	SV * sv_attr
	CODE:
		char *class  = SvPV(sv_class, PL_na);
		char *path   = SvPV(sv_path, PL_na);
		int attr     = SvIV(sv_attr);
		int fd;
		ipc_door_data_t servproc_in, servproc_out;
//		SV sv=*sv_input;
//		SV* referent = SvRV(sv_input);
		door_arg_t arg;
		SV   *output;
		char *s;

		ENTER;
		SAVETMPS;

		if ((fd = open(path, attr)) < 0) {
			PerlIO_printf(PerlIO_stderr(), "open() failed");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
			XSRETURN_UNDEF;
		};

		if ( strncpy((char*)servproc_in.ipc_door_data_pv, SvPV(sv_input, PL_na), MAX_STRING) == NULL )
			XSRETURN_UNDEF;

		arg.data_ptr  = (char *) &servproc_in;
		arg.data_size = sizeof(servproc_in);
		arg.desc_ptr  = NULL;
		arg.desc_num  = 0;
		arg.rbuf      = (char *) &servproc_out;
		arg.rsize     = sizeof(servproc_out);

		if (door_call(fd, &arg) < 0) {
			/* Why did it fail? */
			PerlIO_printf(PerlIO_stderr(), "door_call() failed: ");
			PerlIO_printf(PerlIO_stderr(), strerror(errno));
			PerlIO_printf(PerlIO_stderr(), "\n");
			if (close(fd) < 0) croak ("close() failed\n");
				XSRETURN_UNDEF;
		} else {
//			printf("door_call() succeeded!");
			if (close(fd) < 0) croak ("close() failed\n");
				// we want a string
			if (((char*)s=calloc(MAX_STRING,1)) == NULL)
				XSRETURN_UNDEF;
			output = sv_newmortal();
//			(void)SvUPGRADE(output,SVt_PVNV);
			servproc_out.ipc_door_data_pv[MAX_STRING-1]='\0';
			if ( strncpy(s, servproc_out.ipc_door_data_pv, MAX_STRING) == NULL )
				XSRETURN_UNDEF;
			output = newSVpv( s, 0 );
//			SvNV(output);
//			SvIV(output);
//			sv_dump(output);
			free(s);

			FREETMPS;
			LEAVE;

			RETVAL = (SV *)output;
		}

	OUTPUT:
		RETVAL
