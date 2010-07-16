include $(GNUSTEP_MAKEFILES)/common.make

#
# Main framework
#
BUNDLE_NAME = DBusKitTests

# Include configuration

-include ../config.make
-include ../GNUmakefile.preamble

DBusKitTests_OBJCFLAGS += $(WARN_FLAGS) -I ../Headers
# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
DBusKitTests_OBJCFLAGS += -Werror
endif

DBusKitTests_LDFLAGS=-L../Source/DBusKit.framework/$(GNUSTEP_TARGET_LDIR) -lDBusKit -lUnitKit

DBusKitTests_OBJC_FILES += \
	TestDKArgument.m \
        TestDKMethod.m \
	TestDKMethodCall.m \
        TestDKPort.m \
	TestDKProxy.m

all:: $(BUNDLE_NAME)
	LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:../Source/DBusKit.framework/Versions/Current/$(GNUSTEP_TARGET_LDIR) ukrun $(BUNDLE_NAME).bundle
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

# Quick hack to keep gnustep-make from installing the testcase-bundle:
DBusKitTests.install.bundle.variables::
	@echo "Not installing testcases"
