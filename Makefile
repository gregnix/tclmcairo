#-----------------------------------------------------------------------
# Makefile.in -- tclmcairo
# Wird durch ./configure zu Makefile generiert
#-----------------------------------------------------------------------

PKG_SOURCES  =  src/libtclmcairo.c
PKG_OBJECTS  =  libtclmcairo.o

# VPATH: .c Dateien in Unterverzeichnissen finden
VPATH = ./src
PKG_TCL_SOURCES =  tcl/tclmcairo-0.2.tm
PKG_HEADERS  = 
PKG_LIB_FILE = libtcl9tclmcairo
PKG_DIR      = $(PACKAGE_NAME)$(PACKAGE_VERSION)

PACKAGE_NAME    = tclmcairo
PACKAGE_VERSION = 0.2

CC          = gcc
CLEANFILES  = 
EXEEXT      = 
OBJEXT      = o
RANLIB      = :
RANLIB_STUB = ranlib
SHLIB_LD    = @SHLIB_LD@
SHLIB_LD_LIBS = @SHLIB_LD_LIBS@
SHLIB_SUFFIX = @SHLIB_SUFFIX@
TCL_BIN_DIR = /usr/lib/tcl9.0
TCL_SRC_DIR = /usr/include/tcl9.0/tcl-private
TCL_VERSION = 9.0
# Override: make TCLSH=tclsh9.0 test
TCLSH        = tclsh
INSTALL     = $(SHELL) $(srcdir)/tclconfig/install-sh -c
INSTALL_DATA= ${INSTALL} -m 644
INSTALL_PROGRAM = ${INSTALL} -m 755
INSTALL_SCRIPT = ${INSTALL} -m 755

prefix      = /usr
exec_prefix = /usr
libdir      = ${exec_prefix}/lib
includedir  = ${prefix}/include
datarootdir = ${prefix}/share
datadir     = ${datarootdir}
mandir      = ${datarootdir}/man

PACKAGE_DIR = $(DESTDIR)$(libdir)/$(PKG_DIR)

PKG_CFLAGS  =  -DHAVE_LIBJPEG  -std=c11 -Wall -Wextra

INCLUDES    =  -I/usr/include/cairo -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/pixman-1 -I"/usr/include/tcl9.0/tcl-private/generic" -I"/usr/include/tcl9.0/tcl-private/unix"
DEFINES     = -DPACKAGE_NAME=\"tclmcairo\" -DPACKAGE_TARNAME=\"tclmcairo\" -DPACKAGE_VERSION=\"0.2\" -DPACKAGE_STRING=\"tclmcairo\ 0.2\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DBUILD_tclmcairo=/\*\*/ -DHAVE_STDIO_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_STRINGS_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_UNISTD_H=1 -DSTDC_HEADERS=1 -DUSE_TCL_STUBS=1 -DUSE_TCLOO_STUBS=1 -DUSE_TCL_STUBS

# CFLAGS direkt — keine TEA-internen @VARS@ die nicht substituiert werden
CFLAGS      = -shared -fPIC -O2 \
              $(INCLUDES) $(DEFINES) $(PKG_CFLAGS)

LDFLAGS     =  -lcairo -ljpeg -lm -L/usr/lib/x86_64-linux-gnu -ltclstub9.0 -lm

# ================================================================
# Ziele
# ================================================================

.PHONY: all clean distclean install test binaries libraries

all: binaries libraries

binaries: $(PKG_LIB_FILE)

libraries:

# Compile-Regel: src/*.c -> *.o im Build-Verzeichnis
%.$(OBJEXT): ./src/%.c
	$(CC) -c $(CFLAGS) $< -o $@

%.$(OBJEXT): %.c
	$(CC) -c $(CFLAGS) $< -o $@

# Always build as libtclmcairo.so regardless of TEA naming convention
# Tcl requires: libNAME.so → NAME_Init() = Tclmcairo_Init
TCLMCAIRO_SO = libtclmcairo.so

$(TCLMCAIRO_SO): $(PKG_OBJECTS)
	$(CC) -shared -o $(TCLMCAIRO_SO) $(PKG_OBJECTS) $(LDFLAGS)
	@echo "Built: $(TCLMCAIRO_SO)"

# Keep TEA target working too
$(PKG_LIB_FILE): $(TCLMCAIRO_SO)
	@test -f $(TCLMCAIRO_SO) && cp $(TCLMCAIRO_SO) $(PKG_LIB_FILE) || true

binaries: $(TCLMCAIRO_SO)

# ================================================================
# Install
# ================================================================

install: all install-binaries install-libraries

install-binaries:
	@mkdir -p $(PACKAGE_DIR)
	$(INSTALL_PROGRAM) $(PKG_LIB_FILE) $(PACKAGE_DIR)/$(PKG_LIB_FILE)
	$(INSTALL_DATA)    pkgIndex.tcl    $(PACKAGE_DIR)/pkgIndex.tcl

install-libraries:
	@mkdir -p $(PACKAGE_DIR)
	@for f in $(PKG_TCL_SOURCES); do \
	    echo "Installing $$f"; \
	    $(INSTALL_DATA) $$f $(PACKAGE_DIR)/; \
	done

# ================================================================
# Test
# ================================================================

test: all
	TCLMCAIRO_LIBDIR=. $(TCLSH) tests/test-tclmcairo.tcl

demo: all
	TCLMCAIRO_LIBDIR=. $(TCLSH) demos/demo-tclmcairo.tcl

# ================================================================
# Release ZIP
# ================================================================

zip: distclean
	cd .. && zip -r tclmcairo_$(PACKAGE_VERSION).zip tclmcairo/ \
	    --exclude "*.git*" --exclude "*.bak" --exclude "*.o"
	@echo "Created: ../tclmcairo_$(PACKAGE_VERSION).zip"

# ================================================================
# Clean
# ================================================================

clean:
	-rm -f $(TCLMCAIRO_SO) $(PKG_LIB_FILE) $(PKG_OBJECTS) $(CLEANFILES)

distclean: clean
	-rm -f Makefile pkgIndex.tcl config.cache config.log config.status \
	       src/xdg-shell-client-protocol.h
