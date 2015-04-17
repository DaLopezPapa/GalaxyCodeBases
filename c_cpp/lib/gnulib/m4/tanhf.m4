# tanhf.m4 serial 2
dnl Copyright (C) 2011-2015 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_FUNC_TANHF],
[
  AC_REQUIRE([gl_MATH_H_DEFAULTS])
  AC_REQUIRE([gl_FUNC_TANH])

  dnl Persuade glibc <math.h> to declare tanhf().
  AC_REQUIRE([gl_USE_SYSTEM_EXTENSIONS])

  dnl Test whether tanhf() exists. Assume that tanhf(), if it exists, is
  dnl defined in the same library as tanh().
  save_LIBS="$LIBS"
  LIBS="$LIBS $TANH_LIBM"
  AC_CHECK_FUNCS([tanhf])
  LIBS="$save_LIBS"
  if test $ac_cv_func_tanhf = yes; then
    TANHF_LIBM="$TANH_LIBM"
  else
    HAVE_TANHF=0
    TANHF_LIBM="$TANH_LIBM"
  fi
  AC_SUBST([TANHF_LIBM])
])