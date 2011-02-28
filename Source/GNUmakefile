include $(GNUSTEP_MAKEFILES)/common.make

#
# Main framework
#
FRAMEWORK_NAME = DBusKit

# Include configuration

-include ../config.make

#
# Public headers (will be installed)
#
DBusKit_HEADER_FILES_DIR = ../Headers
DBusKit_HEADER_FILES = \
		  DBusKit.h \
		  DKNotificationCenter.h \
		  DKPort.h \
		  DKPortNameServer.h \
                  DKProxy.h \
                  NSConnection+DBus.h
#
# Class files
#
DBusKit_OBJC_FILES = \
        DKArgument.m \
	DKEndpoint.m \
	DKEndpointManager.m \
	DKInterface.m \
        DKIntrospectionNode.m \
	DKIntrospectionParserDelegate.m \
        DKMessage.m \
        DKMethod.m \
	DKMethodCall.m \
	DKNonAutoInvalidatingPort.m \
	DKNotificationCenter.m \
	DKObjectPathNode.m \
	DKOutgoingProxy.m \
	DKPort.m \
	DKPortNameServer.m \
	DKProperty.m \
	DKPropertyMethod.m \
        DKProxy.m \
	DKSignal.m \
	NSConnection+DBus.m


DBusKit_OBJCFLAGS += $(WARN_FLAGS) 
# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
DBusKit_OBJCFLAGS += -Werror
endif

ifneq ($(findstring gcc, $(CC)),)
  # Make gcc emit the correct code for synchronisation intrinsics
  ifeq ($(GNUSTEP_TARGET_CPU), ix86)
    DBusKit_OBJCFLAGS += -march=i586
  endif
endif


-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make

-include GNUmakefile.postamble
