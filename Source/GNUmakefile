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
	DKPort.m \
        DKProxy.m

ifeq ($(test), yes)
libDBusKit_OBJC_FILES += \
	TestDKArgument.m
endif

-include ../GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make

-include ../GNUmakefile.postamble
