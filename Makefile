#-----------------------------------------------------------------------
# Makefile.in -- tclmcairo
# Wird durch ./configure zu Makefile generiert
#-----------------------------------------------------------------------

PKG_SOURCES  =  src/libtclmcairo.c
PKG_OBJECTS  =  libtclmcairo.o

# VPATH: .c Dateien in Unterverzeichnissen finden
VPATH = ./src
PKG_TCL_SOURCES =  tcl/tclmcairo-0.3.3.tm tcl/canvas2cairo-0.1.tm tcl/shape_renderer-0.1.tm
PKG_HEADERS  = 
PKG_LIB_FILE = libtclmcairo
PKG_DIR      = $(PACKAGE_NAME)$(PACKAGE_VERSION)

PACKAGE_NAME    = tclmcairo
PACKAGE_VERSION = 0.3.3

CC          = gcc
CLEANFILES  = 
EXEEXT      = 
OBJEXT      = o
RANLIB      = :
RANLIB_STUB = ranlib
SHLIB_LD    = @SHLIB_LD@
SHLIB_LD_LIBS = @SHLIB_LD_LIBS@
SHLIB_SUFFIX = @SHLIB_SUFFIX@
TCL_BIN_DIR = /usr/lib/tcl8.6
TCL_SRC_DIR = /usr/include/tcl8.6/tcl-private
TCL_VERSION = 8.6
# TCLSH defaults to the tclsh from the configured Tcl installation.
# Override with: make test TCLSH=/path/to/tclsh
TCLSH        ?= /usr/bin/tclsh8.6
INSTALL         = install
INSTALL_DATA    = install -m 644
INSTALL_PROGRAM = install -m 755
INSTALL_SCRIPT  = install -m 755

prefix      = /usr
exec_prefix = /usr
libdir      = $(prefix)/lib/tcltk
includedir  = ${prefix}/include
datarootdir = ${prefix}/share
datadir     = ${datarootdir}
mandir      = ${datarootdir}/man

PACKAGE_DIR = $(DESTDIR)$(libdir)/$(PKG_DIR)

PKG_CFLAGS  =  -DHAVE_LIBJPEG  -std=c11 -Wall -Wextra

INCLUDES    =  -I/usr/include/cairo -I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include/pixman-1 -I"/usr/include/tcl8.6"
DEFINES     = -DPACKAGE_NAME=\"tclmcairo\" -DPACKAGE_TARNAME=\"tclmcairo\" -DPACKAGE_VERSION=\"0.3.3\" -DPACKAGE_STRING=\"tclmcairo\ 0.3.3\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DBUILD_tclmcairo=/\*\*/ -DHAVE_STDIO_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_STRINGS_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_UNISTD_H=1 -DSTDC_HEADERS=1 -DTcl_Size=int -DUSE_TCL_STUBS=1 -DUSE_TCLOO_STUBS=1 -DTCL_MAJOR_VERSION=8 -DTK_MAJOR_VERSION=8 -DUSE_TCL_STUBS

# CFLAGS direkt — keine TEA-internen @VARS@ die nicht substituiert werden
CFLAGS      = -shared -fPIC -O2 \
              $(INCLUDES) $(DEFINES) $(PKG_CFLAGS)

LDFLAGS     =  -lcairo -ljpeg -lm -L/usr/lib/x86_64-linux-gnu -ltclstub8.6 -lm

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
	$(INSTALL_PROGRAM) $(TCLMCAIRO_SO)  $(PACKAGE_DIR)/$(TCLMCAIRO_SO)
	$(INSTALL_DATA)    pkgIndex.tcl     $(PACKAGE_DIR)/pkgIndex.tcl
	@echo "Installed: $(PACKAGE_DIR)"

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
