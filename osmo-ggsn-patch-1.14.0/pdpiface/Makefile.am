noinst_LIBRARIES = libpdpiface.a

noinst_HEADERS = pdpiface.h

AM_CFLAGS = \
	    -fno-builtin \
	    -Wall \
	    -DSBINDIR='"$(sbindir)"' \
	    -I$(top_srcdir)/include \
	    $(LIBOSMOCORE_CFLAGS) \
	    $(LIBOSMOGSM_CFLAGS) \
	    $(NULL)

libpdpiface_a_SOURCES = pdpiface.c
