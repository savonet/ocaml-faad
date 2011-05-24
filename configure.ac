
# check for one particular file of the sources 
AC_INIT(ocaml-faad, 0.3.0, savonet-users@lists.sourceforge.net)

VERSION=$PACKAGE_VERSION
AC_MSG_RESULT([configuring $PACKAGE_STRING])

# Add prefix to compilation variables
# if passed
if test "x$prefix" != "xNONE"; then
	CFLAGS="$CFLAGS -I$prefix/include"
	LDFLAGS="$LDFLAGS -L$prefix/lib"
	CPPFLAGS="$CPPFLAGS -I$prefix/include"
fi

# Include a config.h
AC_CONFIG_HEADERS([config.h:config.h.in])
# Include it
CFLAGS="$CFLAGS -I`pwd`/`dirname $0` -DHAVE_CONFIG_H"

AC_CHECK_HEADERS([errno.h])

AC_CHECK_OCAML_COMPILERS()

AC_PROG_CC()
AC_CHECK_TOOL([AR],[ar],no)
AC_SUBST(AR)
# Check for libfaad
FAAC_LIBS="-lfaad -lm"
FAAC_CFLAGS=""
FAAC_CPPFLAGS=""
ac_save_CPPFLAGS="$CPPFLAGS"
ac_save_CFLAGS="$CFLAGS"
ac_save_LIBS="$LIBS"
CPPFLAGS="$CPPFLAGS $FAAC_CPPFLAGS"
CFLAGS="$CFLAGS $FAAC_CFLAGS"
LIBS="$FAAC_LIBS $LIBS"
AC_CHECK_HEADERS([neaacdec.h], [
                  AC_CHECK_FUNC([NeAACDecInit], [ac_have_faad="yes"])
])
CPPFLAGS="$ac_save_CPPFLAGS"
CFLAGS="$ac_save_CFLAGS"
LIBS="$ac_save_LIBS"
if test "$ac_have_faad" != "yes"; then
  AC_MSG_ERROR([Cannot find libfaad.])
fi
CPPFLAGS="$CPPFLAGS $FAAC_CPPFLAGS"
CFLAGS="$CFLAGS $FAAC_CFLAGS"
LIBS="$LIBS $FAAC_LIBS"


# substitutions to perform
AC_SUBST(VERSION)

# Finally create the Makefile and samples
AC_CONFIG_FILES([Makefile],[chmod a-w Makefile])
AC_CONFIG_FILES([src/META])
AC_CONFIG_FILES([src/Makefile])
AC_OUTPUT
