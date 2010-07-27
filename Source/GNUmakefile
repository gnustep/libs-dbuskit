include $(GNUSTEP_MAKEFILES)/common.make

#
# Main framework
#
FRAMEWORK_NAME = DBusKit
VERSION = 0.1

# Include configuration

-include ../config.make

#
# Public headers (will be installed)
#
DBusKit_HEADER_FILES_DIR = ../Headers
DBusKit_HEADER_FILES = \
		  DBusKit.h \
		  DKPort.h \
                  DKProxy.h \
                  NSConnection+DBus.h
#
# Class files
#
DBusKit_OBJC_FILES = \
        DKArgument.m \
	DKEndpoint.m \
	DKInterface.m \
        DKIntrospectionNode.m \
	DKIntrospectionParserDelegate.m \
        DKMessage.m \
        DKMethod.m \
	DKMethodCall.m \
	DKOutgoingProxy.m \
	DKPort.m \
        DKProxy.m \
	DKSignal.m \
	NSConnection+DBus.m


DBusKit_OBJCFLAGS += $(WARN_FLAGS)

# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
DBusKit_OBJCFLAGS += -Werror
endif

-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make

-include GNUmakefile.postamble
