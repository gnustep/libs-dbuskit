# autoconf template for the configure script

AC_INIT

PKG_PROG_PKG_CONFIG([])

# FIXME: We need a proper test for libobjc2 for some advanced features (e.g.
# the declared-properties - dbus-properties bridge).
# AC_CHECK_FUNCS(objc_setProperty)
# if test $ac_cv_func_objc_setProperty = yes ; then
#   HAVE_OBJC2=1
# else
#   HAVE_OBJC2=0
# fi

#--------------------------------------------------------------------
# Check for libdbus
#--------------------------------------------------------------------
PKG_CHECK_MODULES(DBUS, dbus-1, HAVE_DBUS=1, HAVE_DBUS=0)
AC_SUBST(DBUS_CFLAGS)
AC_SUBST(DBUS_LIBS)

#--------------------------------------------------------------------
# Check for -Wdeclaration-after-statement (adopted from gnustep-base) 
# TODO: Doing it this way looks really ugly because there is a bunch
#       of other tests executed before the result of the test is
#       printed.
#--------------------------------------------------------------------
AC_MSG_CHECKING(whether the compiler supports -Wdeclaration-after-statement)

saved_CFLAGS="$CFLAGS"
CFLAGS="$CFLAGS -Wdeclaration-after-statement"
AC_COMPILE_IFELSE([AC_LANG_PROGRAM()],HAS_W_DECL_AFTER_STATEMENT=yes,HAS_W_DECL_AFTER_STATEMENT=no)
CFLAGS="$saved_CFLAGS"

AC_MSG_RESULT($HAS_W_DECL_AFTER_STATEMENT)

if test x"$HAS_W_DECL_AFTER_STATEMENT" = x"yes"; then
  WARN_FLAGS="-Wall -Wdeclaration-after-statement"
else
  WARN_FLAGS="-Wall"
fi

AC_SUBST(WARN_FLAGS)

AC_CONFIG_FILES([config.make])

AC_OUTPUT
