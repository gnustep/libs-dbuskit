# autoconf template for the configure script

AC_INIT
LT_INIT
AC_CONFIG_MACRO_DIR([m4])
AC_CANONICAL_SYSTEM

#Override the OBJC variable if it is empty and CC is also set.
if test -n ""; then
  if test -z "$OBJC"; then
    OBJC="$CC"
  fi
fi

AC_PROG_CC(clang gcc cc c1 egcs)
AC_PROG_CC_C99
AC_PROG_CPP
AC_PROG_OBJC(clang gcc objcc objc cc CC)
AX_GCC_FUNC_ATTRIBUTE(visibility)
if test "$ax_cv_have_func_attribute_visibility" = "yes"; then
  HAVE_FUNC_ATTRIBUTE_VISIBILITY=1
else
  HAVE_FUNC_ATTRIBUTE_VISIBILITY=0
fi
AC_LANG(Objective C)
PKG_PROG_PKG_CONFIG([])
AC_LANG_PUSH(C)
AC_MSG_CHECKING([whether the compiler supports atomic operations]);
  AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[typedef int atomic;]],
    [[atomic x; atomic y; __sync_bool_compare_and_swap(&x, y, y + 1);]])],
  have_atomic=yes,
have_atomic=no);
  if test "$have_atomic" = "yes"; then
    AC_MSG_RESULT([yes]);
  else
      AC_MSG_RESULT([no]);
      AC_MSG_ERROR([Please use a compiler that supports atomic operations.]);
  fi
if test "$CC" = "gcc"; then
  saved_CFLAGS="$CFLAGS";
  ATOMIC_CFLAGS="";
  case "$target_cpu" in
    i586*|i686*|i786*)
      ATOMIC_CFLAGS="-march=i586";
      CFLAGS="$saved_CFLAGS $ATOMIC_CFLAGS";
  esac
  AC_MSG_CHECKING([checking whether atomic operations require an external library]);
    AC_LINK_IFELSE([AC_LANG_PROGRAM([[typedef int atomic;]],
      [[atomic x; atomic y; __sync_bool_compare_and_swap(&x, y, y + 1);]])],
    need_linkage=no,
  need_linkage=yes);

  if test "$need_linkage" = "no"; then
    AC_MSG_RESULT([no]);
  else
    AC_MSG_RESULT([yes]);
    saved_LDFLAGS="$LDFLAGS";
    LDFLAGS="$saved_LDFLAGS -lgcc";
    AC_MSG_CHECKING([checking for atomic operations from libgcc]);
      AC_LINK_IFELSE([AC_LANG_PROGRAM([[typedef int atomic;]],
        [[atomic x; atomic y; __sync_bool_compare_and_swap(&x, y, y + 1);]])],
      atomic_in_libgcc=yes,
    atomic_in_libgcc=no);
    if test "$atomic_in_libgcc" = "yes"; then
      AC_MSG_RESULT([yes]);
      MORE_LIBS="$MORE_LIBS -lgcc";
    else
      LDFLAGS="$saved_LDFLAGS";
      AC_MSG_RESULT([no]);
      AC_MSG_ERROR([Could not find library to link for atomic operations.]);
    fi
  fi
fi
AC_LANG_POP(C)

#--------------------------------------------------------------------
# Check for libdbus
#--------------------------------------------------------------------
PKG_CHECK_MODULES(DBUS, dbus-1, HAVE_DBUS=1, HAVE_DBUS=0)
AC_SUBST(DBUS_CFLAGS)
AC_SUBST(DBUS_LIBS)

WARN_FLAGS="-Wall"


if test "$HAVE_DBUS" = "0"; then
  AC_MSG_ERROR(DBusKit requires libdbus.)
fi
saved_CFLAGS="$CFLAGS"
saved_CPPFLAGS="$CPPFLAGS"
CFLAGS="$CFLAGS $DBUS_CFLAGS"
CPPFLAGS="$CPPFLAGS -Werror $DBUS_CFLAGS"

AC_CHECK_HEADERS(dbus/dbus.h,have_dbus_h=yes,have_dbus_h=no)
if test "$have_dbus_h" = "no"; then
  AC_MSG_ERROR(pkg-config claims that libdbus is available but DBusKit is unable to use it.)
fi

CFLAGS="$saved_CFLAGS"
CPPFLAGS="$saved_CPPFLAGS"

AC_MSG_CHECKING(whether the compiler supports -Wno-deprecated-declarations)
saved_CFLAGS="$CFLAGS"
CFLAGS="$CFLAGS -Wno-deprecated-declarations"
AC_COMPILE_IFELSE([AC_LANG_PROGRAM()],HAS_W_NO_DEPRECATED_DECL=yes,HAS_W_NO_DEPRECATED_DECL=no)
CFLAGS="$saved_CFLAGS"

AC_MSG_RESULT($HAS_W_NO_DEPRECATED_DECL)

if test x"$HAS_W_NO_DEPRECATED_DECL" = x"yes"; then
  WARN_FLAGS="$WARN_FLAGS -Wno-deprecated-declarations"
fi

AC_SUBST(WARN_FLAGS)
AC_SUBST(ATOMIC_CFLAGS)

HAVE_LIBCLANG=0

AC_ARG_ENABLE(libclang,
      [  --disable-libclang	Disable use of libclang.],,)

if test "$enable_libclang" != "no"; then
  AC_CHECK_HEADERS("clang-c/Index.h")
  if test "$ac_cv_header_clang_c_Index_h" = "yes"; then
    AC_CHECK_LIB(clang, clang_Cursor_getArgument)
    if test "$ac_cv_lib_clang_clang_Cursor_getArgument" = "yes"; then
      HAVE_LIBCLANG=1;
      MORE_LIBS="$MORE_LIBS -lclang"
    fi
  fi
  if test "$HAVE_LIBCLANG" = "0"; then
    AC_MSG_WARN([Could not find a usable libclang. Please install libclang to enable advanced DBusKit features.])
  fi
fi

AC_SUBST(HAVE_LIBCLANG)


# Setup variables for Objective-C tests:

saved_CFLAGS="$CFLAGS"
saved_CPPFLAGS="$CPPFLAGS"
saved_LDFLAGS="$LDFLAGS"
GS_OBJCFLAGS=`gnustep-config --objc-flags`
CFLAGS="$CFLAGS $GS_OBJCFLAGS"
CPPFLAGS="$CPPFLAGS $GS_OBJCFLAGS"
GS_LDFLAGS=`gnustep-config --objc-libs`
LDFLAGS="$LDFLAGS $GS_LDFLAGS"




#--------------------------------------------------------------------
# Check whether we get runtime.h from libobjc2 or from the ObjectiveC2
# framework
#--------------------------------------------------------------------

CPPFLAGS="$CPPFLAGS -Werror"
AC_CHECK_HEADERS(ObjectiveC2/runtime.h,have_objectivec2_runtime_h=yes,have_objectivec2_runtime_h=no)
if test "$have_objectivec2_runtime_h" = "yes"; then
  OBJC_RUNTIME_H="ObjectiveC2/runtime.h"
else
  AC_CHECK_HEADERS(objc/runtime.h,have_libobjc2_runtime_h=yes,have_libobjc2_runtime_h=no)
  if test "$have_libobjc2_runtime_h" = "yes"; then
    OBJC_RUNTIME_H="objc/runtime.h"
  else
    AC_MSG_ERROR("could not find runtime.h. DBusKit requires gnustep-base >=1.20.")
  fi
fi

AC_CHECK_HEADERS([objc/encoding.h], [have_objc_encoding_h=yes], [have_objc_encoding_h=no],
  [#ifdef HAVE_OBJC_RUNTIME_H
   #include <objc/runtime.h>
   #else
   #  ifdef HAVE_OBJECTIVEC2_RUNTIME_H
   #  include <ObjectiveC2/runtime.h>
   #  endif
   #endif
])

if test "$have_objc_encoding_h" = "yes"; then
	HAVE_OBJC_ENCODING_H=1
else
	HAVE_OBJC_ENCODING_H=0
fi

CPPFLAGS="$saved_CPPFLAGS"

# We also need to set the libs because the order does sometimes matter.
LIBS=`gnustep-config --objc-libs`
AC_CHECK_FUNCS(sel_getType_np, [have_sel_getType_np=yes],
  [have_sel_getType_np=no;
   AC_CHECK_FUNCS(sel_getTypeEncoding, [have_sel_getTypeEncoding=yes],
   [have_sel_getTypeEncoding=no])
  ]
)

USE_SEL_GETTYPEENCODING=0
DISABLE_TYPED_SELECTORS=0
if test "$have_sel_getType_np" = "no"; then
  if test "$have_sel_getTypeEncoding" = "yes"; then
    USE_SEL_GETTYPEENCODING=1;
  else
    DISABLE_TYPED_SELECTORS=1
  fi
fi

C99_FLAGS=$ac_cv_prog_cc_c99
AC_SUBST(C99_FLAGS)
AC_SUBST(HAVE_OBJC_ENCODING_H)
AC_SUBST(OBJC_RUNTIME_H)
AC_SUBST(OBJC)
AC_SUBST(USE_SEL_GETTYPEENCODING)
AC_SUBST(DISABLE_TYPED_SELECTORS)
AC_SUBST(HAVE_FUNC_ATTRIBUTE_VISIBILITY)

CFLAGS="$saved_CFLAGS"
CPPFLAGS="$saved_CPPFLAGS"
LDFLAGS="$saved_LDFLAGS"

AC_SUBST(MORE_LIBS)
AC_CONFIG_FILES([config.make Source/config.h])

AC_OUTPUT
