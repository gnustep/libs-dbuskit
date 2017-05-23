ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif
include ../../config.make

BUNDLE_NAME = NSUserNotification

ADDITIONAL_LIB_DIRS += -L../../Source/DBusKit.framework/Versions/Current/$(GNUSTEP_TARGET_LDIR)
NSUserNotification_NEEDS_GUI = NO
NSUserNotification_LDFLAGS += -lDBusKit
NSUserNotification_PRINCIPAL_CLASS = DKUserNotificationCenter
NSUserNotification_OBJC_FILES = DKUserNotification.m

saved_FOUNDATION_LIB := $(FOUNDATION_LIB)
FOUNDATION_LIB = gnu
ifeq ($(strip $(BASE_MAKEFILE)),)
  include $(GNUSTEP_MAKEFILES)/Additional/base.make
else
  include $(BASE_MAKEFILE)
endif
FOUNDATION_LIB = $(saved_FOUNDATION_LIB)


libgnustep-base_INTERFACE_VERSION=$(GNUSTEP_BASE_MAJOR_VERSION).$(GNUSTEP_BASE_MINOR_VERSION)
NSUserNotification_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Libraries/gnustep-base/Versions/$(libgnustep-base_INTERFACE_VERSION)/Resources/

include $(GNUSTEP_MAKEFILES)/common.make
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
