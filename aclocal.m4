builtin(include,tclconfig/tcl.m4)

dnl AX_CHECK_COMPILE_FLAG -- Hilfsmakro für Compiler-Flag-Tests
AC_DEFUN([AX_CHECK_COMPILE_FLAG], [
  AC_MSG_CHECKING([whether compiler accepts $1])
  ac_save_CFLAGS="$CFLAGS"
  CFLAGS="$CFLAGS $1"
  AC_COMPILE_IFELSE([AC_LANG_PROGRAM([],[])], [
    AC_MSG_RESULT([yes])
    m4_default([$2], [:])
  ], [
    AC_MSG_RESULT([no])
    m4_default([$3], [:])
  ])
  CFLAGS="$ac_save_CFLAGS"
])
