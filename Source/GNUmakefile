include $(GNUSTEP_MAKEFILES)/common.make

#
# Main framework
#
SUBPROJECT_NAME = libDBusKit

# Include configuration

-include ../config.make

#
# Class files
#
libDBusKit_OBJC_FILES = \
        DKArgument.m \
	DKEndpoint.m \
	DKInterface.m \
        DKIntrospectionNode.m \
        DKMethod.m \
	DKPort.m \
        DKProxy.m


libDBusKit_OBJCFLAGS += $(WARN_FLAGS)

# Treat warnings as errors unless someone chooses to ignore them.
ifneq ($(nonstrict), yes)
libDBusKit_OBJCFLAGS += -Werror
endif

ifeq ($(test), yes)
libDBusKit_OBJC_FILES += \
	Tests/TestDKArgument.m \
        Tests/TestDKMethod.m \
        Tests/TestDKPort.m \
	Tests/TestDKProxy.m
endif

-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make

-include GNUmakefile.postamble
