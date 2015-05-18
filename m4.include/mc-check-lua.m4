dnl
dnl This code is called after the Lua engine had been found and pulled in.
dnl It checks the system's consistency and engine's features.
dnl
dnl @author Mooffie
dnl @license GPL
dnl @copyright Free Software Foundation, Inc.

AC_DEFUN([MC_CHECK_LUA], [

    old_CPPFLAGS=$CPPFLAGS
    old_LIBS=$LIBS
    CPPFLAGS="$CPPFLAGS $LUA_CFLAGS"
    LIBS="$LIBS $LUA_LIBS"

    AC_CHECK_HEADER([lua.h], [], [AC_MSG_ERROR([I cannot find Lua's <lua.h> header. Something is probably amiss with the '-I' preprocessor switch.])])
    AC_CHECK_FUNC([lua_pushstring], [], [AC_MSG_ERROR([I cannot link against the Lua engine. Something is probably amiss with the LIBS variable. Examine 'config.log' for the exact error.])])

    AC_CHECK_FUNC([luaJIT_setmode],
        [
            lua_engine_title="LuaJIT"
            AC_DEFINE([HAVE_LUAJIT], [1], [Define if using LuaJIT.])
        ],
        [
            AC_CHECK_FUNC([lua_isinteger],
                [
                    lua_engine_title="Lua 5.3"
                    AC_CHECK_FUNC([lua_rotate], [:], [
                        dnl For our sample scripts we need a math.floor() that knows to return integers,
                        dnl and also math.tointger(). Older 'work' versions are problematic with these.
                        AC_MSG_ERROR([You are using a 'work' version of Lua 5.3. It's outdated. I require at least the 'alpha' version.])
                    ])
                ],
                [
                    AC_CHECK_FUNC([lua_callk], [lua_engine_title="Lua 5.2"], [
                        AC_CHECK_FUNC([luaL_newstate], [lua_engine_title="Lua 5.1"], [
                            AC_MSG_ERROR([You seem to be using an old version of Lua. I require at least Lua 5.1 (Lua 5.0 is NOT supported).])
                        ])
                    ])
                ]
            )
        ]
    )

    dnl Make SIZEOF_LUA_INTEGER and SIZEOF_LUA_NUMBER available to the C preprocessor.
    AC_CHECK_SIZEOF([lua_Integer], [], [
        #include <lua.h>
    ])
    AC_CHECK_SIZEOF([lua_Number], [], [
        #include <lua.h>
    ])

    dnl Features test.
    AC_CHECK_FUNCS([lua_absindex luaL_getsubtable lua_rawlen luaL_testudata lua_getfenv luaL_setfuncs luaL_typerror])
    AC_CHECK_FUNCS([lua_pushunsigned luaL_checkunsigned luaL_checkint luaL_checklong luaL_optint luaL_optlong])
    AC_CHECK_FUNCS([luaL_setmetatable lua_isinteger])

    CPPFLAGS=$old_CPPFLAGS
    LIBS=$old_LIBS

    echo
    echo "  LUA ENGINE: $lua_engine_title"
    echo
])
