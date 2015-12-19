
noinst_LTLIBRARIES = libmc-lualib.la

libmc_lualib_la_SOURCES = \
	capi.c \
	capi.h \
	capi-safecall.c \
	capi-safecall.h \
	plumbing.c \
	plumbing.h \
	timer.c \
	timer.h \
	ui-impl.c \
	ui-impl.h \
	utilx.c \
	utilx.h

AM_CPPFLAGS = \
	-DMC_LUA_SYSTEM_DIR=\""$(mcluasystemdir)"\" \
	-I$(top_srcdir) $(GLIB_CFLAGS) $(PCRE_CPPFLAGS) $(LUA_CFLAGS)
