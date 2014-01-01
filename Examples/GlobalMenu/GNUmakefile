ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif


include $(GNUSTEP_MAKEFILES)/common.make


#
# Main
#
BUNDLE_NAME = GlobalMenu
BUNDLE_EXTENSION = .theme
VERSION = 1

GlobalMenu_PRINCIPAL_CLASS = GlobalMenuTheme
GlobalMenu_INSTALL_DIR=$(GNUSTEP_LIBRARY)/Themes

#
# Class files
#
GlobalMenu_OBJC_FILES = \
		GlobalMenuTheme.m \

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
