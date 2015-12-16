dnl Enable LuaFS filesystem
AC_DEFUN([mc_VFS_LUAFS],
[
    AC_ARG_ENABLE([vfs-luafs],
                  AS_HELP_STRING([--enable-vfs-luafs], [Support for LuaFS filesystem [auto]]))

    if test "$enable_vfs" = "yes" -a x"$enable_vfs_luafs" != x"no"; then
        if test -n "$with_lua"; then
            mc_VFS_ADDNAME([luafs])
            AC_DEFINE([ENABLE_VFS_LUAFS], [1], [Support for LuaFS filesystem])
            enable_vfs_luafs="yes"
        else
            if test x"$enable_vfs_luafs" = x"yes"; then
                dnl user explicitly requested feature
                AC_ERROR([Since Lua support was not enabled (see '--with-lua'), you cannot enable LuaFS, which depends on it.])
            fi
            enable_vfs_luafs="no"
        fi
    fi

    AM_CONDITIONAL([ENABLE_VFS_LUAFS], [test "$enable_vfs" = "yes" -a x"$enable_vfs_luafs" = x"yes"])
])
