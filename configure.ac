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

PKG_CHECK_MODULES(DBUS, dbus-1, HAVE_DBUS=1, HAVE_DBUS=0)
AC_SUBST(DBUS_CFLAGS)
AC_SUBST(DBUS_LIBS)

AC_CONFIG_FILES([config.make])

AC_OUTPUT
