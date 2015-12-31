dnl @author Mooffie
dnl @license GPL
dnl @copyright Free Software Foundation, Inc.

AC_DEFUN([MC_PRINTF_I18N_GROUPING],
[
    gt_GLIBC2

    AC_CACHE_CHECK([whether printf() can print localized thousand separators.],
        [mc_cv_printf_i18n_grouping],
        [
            grouping=no

            dnl Since runtime detection doesn't work when cross-compiling, we first
            dnl test for the existence of a decent glibc library.

            AS_IF([test x"$GLIBC2" = xyes], [grouping=yes], [
                AC_MSG_NOTICE([** TRYING RUNTIME DETECTION])
                AC_RUN_IFELSE([AC_LANG_SOURCE([[
#include <stdio.h>
#include <string.h>
int main ()
{
  /* We merely check that the "'" doesn't break anything. If it
   * doesn't, we assume we have i18n support. */
  char buf[100];
  sprintf (buf, "%'d", 123);
  return (strcmp (buf, "123") != 0);
}
                ]])], [grouping=yes], [:], [:])
            ])

            mc_cv_printf_i18n_grouping=$grouping
        ])

    if test x"$mc_cv_printf_i18n_grouping" = xyes; then
        AC_DEFINE(HAVE_PRINTF_I18N_GROUPING, [1], [Define if printf() and family can print localized thousands separators for numbers.])
    fi

])
