include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECT_NAME = DBUS

DBUS_OBJC_FILES = \
		   DBUSConnection.m \
		   DBUSIntrospector.m \
		   DBUSMessage.m \
		   DBUSMessageCall.m \
		   DBUSMessageIterator.m \
		   DBUSMessagePort.m \
		   DBUSMessageReturn.m \
		   DBUSPortNameServer.m \
		   DBUSProxy.m \
		   DBUSServer.m

ifneq ($(test), no)
DBUS_OBJC_FILES += \
		   TestIntrospector.m \
		   TestMessageIterator.m \
		   TestFunctional.m
endif

ifneq ($(test), no)
ifeq ($(FOUNDATION_LIB), apple)
${BUNDLE_NAME}_OBJC_LIBS += -framework UnitKit
else
${BUNDLE_NAME}_OBJC_LIBS = -lUnitKit
endif
endif

include ../config.make

include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/subproject.make
