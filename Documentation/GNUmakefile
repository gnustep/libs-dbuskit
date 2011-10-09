include $(GNUSTEP_MAKEFILES)/common.make
-include ../GNUmakefile.preamble

DOCUMENT_NAME = DBusKit

DBusKit_TEXI_FILES = 	DBusKit.texi \
			Introduction.texi \
			fdl-1.3.texi

DBusKit_DOC_INSTALL_DIR = Developer/DBusKit/ProgrammingManual

DOCUMENT_TEXT_NAME = INSTALL README ANNOUNCE

INSTALL_TEXT_MAIN = install.texi
INSTALL_TEXI_FILES = install.texi
INSTALL_DOC_INSTALL_DIR = Developer/DBusKit/ReleaseNotes/$(VERSION)

ANNOUNCE_TEXT_MAIN = announce.$(VERSION).texi
ANNOUNCE_TEXI_FILES = announce.$(VERSION).texi
ANNOUNCE_DOC_INSTALL_DIR = Developer/DBusKit/ReleaseNotes/$(VERSION)

README_TEXT_MAIN = readme.texi
README_TEXI_FILES = readme.texi
README_DOC_INSTALL_DIR = Developer/DBusKit/ReleaseNotes/$(VERSION)

MAN1_PAGES= dk_make_protocol.1

REF_DOC_INSTALL_DIR = $(GNUSTEP_DOC)/Developer

DBusKit_AGSDOC_FLAGS = \
	-MakeFrames YES \
	-DocumentationDirectory Reference \
	-HeaderDirectory ../Headers/ \
	-Declared DBusKit \
	-ConstantsTemplate TypesAndConstants \
	-FunctionsTemplate Functions \
	-MacrosTemplate Functions \
	-TypedefsTemplate TypesAndConstants \
	-VariablesTemplate TypesAndConstants
DBusKit_AGSDOC_FILES = \
	DBusKit.gsdoc \
	../Headers/DKNotificationCenter.h \
	../Headers/DKPort.h \
	../Headers/DKProxy.h 

include $(GNUSTEP_MAKEFILES)/documentation.make
-include GNUmakefile.postamble
