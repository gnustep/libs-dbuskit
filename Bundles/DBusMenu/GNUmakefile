include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = DBusMenu
DBusMenu_OBJC_FILES = DKMenuProxy.m \
		      DKMenuRegistry.m 

DBusMenu_HEADER_FILES = DKMenuProxy.h \
			DKMenuRegistry.h \
			DKDBusMenu.h

ADDITIONAL_LIB_DIRS += -L../../Source/DBusKit.framework/Versions/Current/$(GNUSTEP_TARGET_LDIR)
DBusMenu_BUNDLE_LIBS += -lDBusKit
DBusMenu_NEEDS_GUI = YES
DBusMenu_PRINCIPAL_CLASS = DKMenuRegistry
DBusMenu_RESOURCE_FILES = \
  com.canonical.dbusmenu.xml
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
