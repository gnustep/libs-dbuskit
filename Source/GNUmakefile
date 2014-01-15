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
		  DKCommon.h \
		  DKNotificationCenter.h \
		  DKNumber.h \
		  DKPort.h \
		  DKPortNameServer.h \
                  DKProxy.h \
		  DKStruct.h \
		  DKVariant.h \
                  NSConnection+DBus.h
#
# Class files
#
DBusKit_OBJC_FILES = \
        DKArgument.m \
	DKBoxingUtils.m \
	DKEndpoint.m \
	DKEndpointManager.m \
	DKInterface.m \
        DKIntrospectionNode.m \
	DKIntrospectionParserDelegate.m \
        DKMessage.m \
        DKMethod.m \
	DKMethodCall.m \
	DKMethodReturn.m \
	DKNonAutoInvalidatingPort.m \
	DKNotificationCenter.m \
	DKNumber.m \
	DKObjectPathNode.m \
	DKOutgoingProxy.m \
	DKPort.m \
	DKPortNameServer.m \
	DKProperty.m \
	DKPropertyMethod.m \
        DKProxy.m \
	DKSignal.m \
	DKSignalEmission.m \
	DKStruct.m \
	DKVariant.m \
	NSConnection+DBus.m


DBusKit_OBJCFLAGS += $(WARN_FLAGS) 
# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
DBusKit_OBJCFLAGS += -Werror
endif

LIBRARIES_DEPEND_UPON = $(FND_LIBS) $(OBJC_LIBS)

-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/framework.make

-include GNUmakefile.postamble
