#
# GNUmakefile for DBusKit tools
#

include $(GNUSTEP_MAKEFILES)/common.make

# config.make will be generated at configure time
-include ../config.make

GNUSTEP_USE_PARALLEL_AGGREGATE=yes

TOOL_NAME = dk_make_protocol

dk_make_protocol_OBJC_FILES=dk_make_protocol.m

ADDITIONAL_LIB_DIRS += -L../Source/DBusKit.framework/Versions/Current/$(GNUSTEP_TARGET_LDIR)
ADDITIONAL_TOOL_LIBS = -lgnustep-base -lDBusKit

#
# Makefiles
#
-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
