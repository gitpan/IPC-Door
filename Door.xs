/*
$Date: 2003/08/29 00:50:37 $
$Id: Door.xs,v 1.14 2003/08/29 00:50:37 asari Exp $
*/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <stropts.h>
#include <door.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

// gcc does not define these
#ifndef TRUE
#define TRUE  1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#define FILE_MODE (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)

// Debugging code ( taken from Storable module )
#ifdef DEBUGME
#define TRACEME(x) STMT_START { \
	if (SvTRUE(perl_get_sv("IPC::Door::DEBUGME", TRUE))) \
		{ PerlIO_stdoutf x; PerlIO_stdoutf("\n"); } \
} STMT_END
#else
#define TRACEME(x)
#endif

/* static SV * serv_sv; */


/* The server process */
void servproc(void *cookie, char *dataptr, size_t datasize,
	door_desc_t *descptr, size_t ndesc)
{
	
	dSP;
	double arg = *((double *) dataptr);
	double result;
	int count;	/* number of elements returned from Perl */
	
	ENTER;
	SAVETMPS;
	
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVnv(arg)));
	
	PUTBACK;

	count = call_pv("main::serv", G_SCALAR);
	
	SPAGAIN;
	
	if (count != 1)
		croak ( "Big, big trouble\n" );
	
	result = POPn;
	door_return( (char *) &result, sizeof(result),NULL,0);
	
	PUTBACK;
	

	FREETMPS;
	LEAVE;

}



/*
Start XSUB
*/

MODULE=IPC::Door	PACKAGE=IPC::Door


int
__create( sv_class, sv_path, code)
	SV *sv_class
	SV *sv_path
	SV *code
	PROTOTYPE: $$$
	CODE:
		char *class = SvPV( sv_class, PL_na );
		int fd;
		char *path = SvPV( sv_path, PL_na );
		//serv_sv = code;
		fd = door_create( servproc, NULL, 0 );
		close(open( path, O_CREAT | O_RDWR, FILE_MODE ));
		RETVAL = fattach (fd, path);
	OUTPUT:
		RETVAL


double
__call( sv_class, sv_path, sv_input )
	SV * sv_class
	SV * sv_path
	SV * sv_input
	CODE:
		char *class = SvPV( sv_class, PL_na );
		char *path = SvPV( sv_path, PL_na );
		double input = SvNV( sv_input );
		int fd;
		door_arg_t arg;
		double output;

		fd = open(path, O_RDWR);


		arg.data_ptr = (char *) &input;
		arg.data_size = sizeof(double);
		arg.desc_ptr = NULL;
		arg.desc_num = 0;
		arg.rbuf = (char *) &output;
		arg.rsize = sizeof(double);

		if ( door_call(fd, &arg) == 0 ) {
			TRACEME(("door_call() successful!"));
			close(fd);
			RETVAL = output;
		} else {
			TRACEME(("door_call() failed."));
			printf("ERRNO: %d\n",errno);
			// this return value is meaningful only if -1 is not
			// expected to be a legitimate value
			close(fd);
			RETVAL = -1;
		}

	OUTPUT:
		RETVAL
