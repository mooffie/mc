SUBDIRS = library

# The following option is meant to prevent a clash when two files with the same
# name reside in this tree (in two different directories, of course). We have _no_
# such issue in our project, but nevertheless this option has a cute by-product:
# it displays the "modules/" prefix as it compiles. That's nice to have.
AUTOMAKE_OPTIONS = subdir-objects

noinst_LTLIBRARIES = libmc-luasrc.la

libmc_luasrc_la_SOURCES = \
	modules.c \
	modules.h \
	pre-init.h \
	modules/conf.c \
	modules/fs.c \
	modules/fs.h \
	modules/fs-dir.c \
	modules/fs-filedes.c \
	modules/fs-statbuf.c \
	modules/fs-vpath.c \
	modules/internal.c \
	modules/locale.c \
	modules/mc.c \
	modules/os.c \
	modules/prompts.c \
	modules/regex.c \
	modules/timer.c \
	modules/tty.c \
	modules/tty.h \
	modules/ui.c \
	modules/ui-canvas.c \
	modules/ui-canvas.h \
	modules/ui-custom.c \
	modules/ui-custom.h \
	modules/utils-bit32.c \
	modules/utils-text.c \
	modules/utils-text-transport.c

AM_CPPFLAGS = -I$(top_srcdir) $(GLIB_CFLAGS) $(PCRE_CPPFLAGS) $(LUA_CFLAGS)

libmc_luasrc_la_LIBADD = ../../lib/libmc.la

include extra-files-to-dist.mk
EXTRA_DIST = $(extra_files_to_dist)
