dnl @author Mooffie
dnl @license GPL
dnl @copyright Free Software Foundation, Inc.

AC_DEFUN([MC_WITH_LUA], [

    AC_ARG_WITH([lua],
        AS_HELP_STRING([--with-lua@<:@=PKG@:>@],
            [Enable Lua support]
        ),
        [:],
        [with_lua=no]        dnl In the future we'll automatically enable Lua if it exists on the system.
    )

    if test x"$with_lua" = xno; then

        with_lua=

    elif test -n "$LUA_CFLAGS" -o -n "$LUA_LIBS"; then

        with_lua=custom

    else

        dnl Packages don't have standard names so we have to try variations.
        dnl E.g., on Debian it's "lua5.1" but on FreeBSD it's "lua-5.1".
        tries51="lua5.1 lua-5.1 lua51"
        tries52="lua5.2 lua-5.2 lua52"
        tries53="lua5.3 lua-5.3 lua53"
        triesjit="luajit"

        case "$with_lua" in

            # Officially, we ask users to type "--with-lua=lua5.1" etc., but they're
            # likely to type "--with-lua=5.1" instead, so we accommodate for that as well.

            lua5.1|5.1) tries=$tries51  ;;
            lua5.2|5.2) tries=$tries52  ;;
            lua5.3|5.3) tries=$tries53  ;;
            luajit|jit) tries=$triesjit ;;
            yes|"")
                    dnl When no Lua package is explicitly specified:
                    dnl
                    dnl Currently, we try them in this order: LuaJIT, 5.3, 5.2, 5.1.
                    dnl The decision to put LuaJIT first is arbitrary. We may want to
                    dnl revisit this ordering issue in the future.
                    dnl
                    dnl The trailing "lua" might be Lua 5.0, which is why it's the last try. If
                    dnl it's indeed 5.0, which we don't support, we'll detect this in the
                    dnl tests that are to follow.
                    tries="$triesjit $tries53 $tries52 $tries51 lua" ;;
            *)
                    dnl Search for a package named explicitly.
                    tries=$with_lua ;;
        esac

        with_lua=
        for try in $tries; do
            AC_MSG_NOTICE([looking for package '$try'...])
            PKG_CHECK_MODULES([LUA], [$try],
                [
                    with_lua=$try
                    break
                ],
                [:])
        done

        if test -z "$with_lua"; then
            AC_MSG_ERROR([I could not find your Lua engine. Instead of relying on pkg-config you may sepcify LUA_CFLAGS and LUA_LIBS explicitly. Please see instructions in src/lua/doc/10-installation.md.])
        fi

    fi

    if test -n "$with_lua"; then
        AC_DEFINE(USE_LUA, 1, [Define to use Lua])
    fi

    if test -n "$with_lua"; then
        echo
        echo "  LUA ENGINE PACKAGE: '$with_lua'"
        echo "  RESULTS: $LUA_CFLAGS, $LUA_LIBS"
        echo
    else
        echo
        echo "  LUA ENGINE PACKAGE: NONE REQUESTED"
        echo
    fi
])
