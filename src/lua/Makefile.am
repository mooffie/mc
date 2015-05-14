SUBDIRS = library

# The following is needed because we have both 'timer.c' and 'modules/timer.c'
# See http://stackoverflow.com/questions/917948/automake-and-files-with-the-same-name
AUTOMAKE_OPTIONS = subdir-objects

noinst_LTLIBRARIES = libmclua.la

libmclua_la_SOURCES = \
	plumbing.c \
	plumbing.h \
	capi-safecall.c \
	capi-safecall.h \
	capi.c \
	capi.h \
	timer.c \
	timer.h \
	utilx.c \
	utilx.h \
	modules.c \
	modules.h \
	modules/conf.c \
	modules/fs.c \
	modules/fs.h \
	modules/fs-dir.c \
	modules/fs-filedes.c \
	modules/fs-statbuf.c \
	modules/fs-vpath.c \
	modules/prompts.c \
	modules/internal.c \
	modules/tty.c \
	modules/tty.h \
	modules/locale.c \
	modules/utils-bit32.c \
	modules/utils-text.c \
	modules/utils-text-transport.c \
	modules/regex.c \
	modules/timer.c \
	modules/mc.c \
	modules/os.c \
	modules/fields.c \
	modules/fields.h \
	modules/ui-impl.c \
	modules/ui-impl.h \
	modules/ui.c \
	modules/ui-canvas.c \
	modules/ui-canvas.h \
	modules/ui-custom.c \
	modules/ui-custom.h \
	modules/ui-viewer.c \
	modules/ui-panel.c

if USE_INTERNAL_EDIT
    libmclua_la_SOURCES += modules/ui-editbox.c
endif

AM_CPPFLAGS = \
	-DMC_LUA_SYSTEM_DIR=\""$(mcluasystemdir)"\" \
	-I$(top_srcdir) $(GLIB_CFLAGS) $(PCRE_CPPFLAGS) $(LUA_CFLAGS)

libmclua_la_LIBADD = ../../lib/libmc.la

include extra-files-to-dist.mk
EXTRA_DIST = $(extra_files_to_dist)
