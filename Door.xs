/*
$Id: Door.xs,v 1.43 2004/05/06 05:51:01 asari Exp $
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
#define MAX_STRING 16300

/* typedefs */
typedef struct {
    char ipc_door_data_pv[MAX_STRING];
    int  cur;
    int  len;
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
    register SV *sv;          /* convenience variable */
    void        *tmp;
    char        *str;
    int         count;
            /* number of elements returned from sv_callback in Perl */

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);

/*    printf("datasize: %d, sizeof(arg): %d\n", datasize, sizeof(arg));
*/
    memmove(&arg, dataptr, min(datasize,sizeof(arg)));
    if ((str = calloc(MAX_STRING, 1)) == NULL)
        return;
    arg.ipc_door_data_pv[MAX_STRING-1]='\0';
    memmove((void*)str, arg.ipc_door_data_pv, MAX_STRING);

    sv=sv_newmortal();
    sv_callback=sv_newmortal();
    sv_callback = (SV *) cookie;
    sv = newSVpv( "", 0 );
    SvGROW(sv,MAX_STRING);
    memmove((void*)SvPVX(sv), str, MAX_STRING);
    SvCUR(sv)=arg.cur;
    SvLEN(sv)=arg.len;

    free(str);


    if (SvOK(sv))
        XPUSHs(sv);
    else {
        /* fall through; we shouldn't be here, but you never know. */
        Perl_croak("Something went horribly wrong in servproc");
        return;
    }

    PUTBACK;

    /* grab the client's credentials before calling &main::serv */
    if (door_cred(&info) < 0)
        Perl_warn("door_cred() failed");

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
    memmove(retval.ipc_door_data_pv, str, MAX_STRING);
    retval.cur=SvCUR(result);
    retval.len=SvLEN(result);

    if (door_return((char *) &retval, sizeof(retval),NULL,0) < 0)
        Perl_croak("door_return() failed in servproc");

    PUTBACK;

    FREETMPS;
    LEAVE;

}

/*
Start XSUB
*/

MODULE=IPC::Door    PACKAGE=IPC::Door

INCLUDE: const-xs.inc

int
is_door(sv)
    SV * sv
PREINIT:
    char*       path;
    HV*         hv;
    SV**        svp;
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
        warn("%s is not a door\n", path);
        XSRETURN_UNDEF;
    }
    /* path is a door, so gather info */
    if (door_info(fd, &info) < 0) {
        warn("door_info() failed");
    } else {
        XPUSHs(sv_2mortal(newSViv((long) info.di_target)));
        XPUSHs(sv_2mortal(newSViv((long) info.di_attributes)));
        XPUSHs(sv_2mortal(newSViv((long) info.di_uniquifier)));
    }

    if (close(fd) < 0) croak("close() failed\n");



MODULE=IPC::Door    PACKAGE=IPC::Door::Server
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

    /* Make sure sv_server is sane */
    if (!sv_isobject(sv_class)) {
        warn("Non-object passed in __create()");
        XSRETURN_UNDEF;
    }

    /* Make sure that sv_callback is sane */
    if (!SvROK(sv_callback) || (SvTYPE(SvRV(sv_callback)) != SVt_PVCV)) {
        warn("%s is not a code reference.", callback);
        XSRETURN_UNDEF;
    }

    /* set sv_callback */
    sv_callback = *(hv_fetch((HV *)sv_server, "callback", 8, FALSE));

    if ((fd = door_create(servproc, sv_callback, 0)) < 0) {
        /* Why did it fail? */
        warn("door_create() failed");
        if (close(fd) < 0) warn("close() failed\n");
        XSRETURN_UNDEF;
    } else {
        /* need to trap potential errors here */
        close(open(path, O_CREAT | O_RDWR, FILE_MODE));
        if ( (RETVAL=fattach(fd, path)) < 0) {
            warn("fattach() failed");
            XSRETURN_UNDEF;
        }
    }


MODULE=IPC::Door    PACKAGE=IPC::Door::Client
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
    door_arg_t arg;
    SV   *output;
    char *s;

    ENTER;
    SAVETMPS;

    if ((fd = open(path, attr)) < 0) {
        warn("Failed to open %s",path);
        XSRETURN_UNDEF;
    };

    if ( memmove((char*)servproc_in.ipc_door_data_pv, SvPV(sv_input, PL_na), MAX_STRING) == NULL )
        XSRETURN_UNDEF;
    else {
        servproc_in.cur=(int)SvCUR(sv_input);
        servproc_in.len=(int)SvLEN(sv_input);
    };

    arg.data_ptr  = (char *) &servproc_in;
    arg.data_size = sizeof(servproc_in);
    arg.desc_ptr  = NULL;
    arg.desc_num  = 0;
    arg.rbuf      = (char *) &servproc_out;
    arg.rsize     = sizeof(servproc_out);

    if (door_call(fd, &arg) < 0) {
        warn("door_call() failed");
        if (close(fd) < 0) croak ("close() failed\n");
        XSRETURN_UNDEF;
    } else {
        if (close(fd) < 0) croak ("close() failed\n");

        /* Coerce output into something we can return to perl */
        /* Newz(0, (void*)s, 1, typeof(servproc_in.ipc_door_data_pv)); */
        if (((char*)s=calloc(MAX_STRING,sizeof(char))) == NULL)
            XSRETURN_UNDEF;
        output = sv_newmortal();
        servproc_out.ipc_door_data_pv[MAX_STRING-1]='\0';
        if ( memmove(s, servproc_out.ipc_door_data_pv, MAX_STRING) == NULL )
            XSRETURN_UNDEF;
        output = newSVpv( "", 0 );
        SvGROW(output,MAX_STRING);
        memmove((void*)SvPVX(output), s, MAX_STRING);
        /* Move(s,SvPVX(output),1,typeof(servproc_in.ipc_door_data_pv)); */
        SvCUR(output) = servproc_out.cur;
        SvLEN(output) = servproc_out.len;
        free(s);

        FREETMPS;
        LEAVE;

        RETVAL = (SV *)output;
    }
OUTPUT:
    RETVAL
