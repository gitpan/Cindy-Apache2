/* $Id: $
 * Generate by enabling ap_make_content_type in mod_perl 2.0.5.
 * Includes and MODULE adapted.
 */

/*
 * *********** WARNING **************
 * This file generated by ModPerl::WrapXS/0.01
 * Any changes made here will be lost
 * ***********************************
 * 01: /home/jo/libapache2-mod-perl2-2.0.5/blib/lib/ModPerl/WrapXS.pm:540
 * 02: /home/jo/libapache2-mod-perl2-2.0.5/blib/lib/ModPerl/WrapXS.pm:1174
 * 03: Makefile.PL:424
 * 04: Makefile.PL:326
 * 05: Makefile.PL:57
 */



#define MP_IN_XS

#include <mod_perl.h>

#include <modperl_xs_sv_convert.h>

#include <modperl_xs_util.h>

#include <modperl_xs_typedefs.h>

MODULE = Cindy::Apache2   PACKAGE = Cindy::Apache2::RequestRec PREFIX = ap_

const char *
ap_make_content_type(r, type)
    Apache2::RequestRec r
    const char * type


MODULE = Cindy::Apache2
PROTOTYPES: disabled

BOOT:
    items = items; /* -Wall */

