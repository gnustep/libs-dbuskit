include $(GNUSTEP_MAKEFILES)/common.make
SERVICE_NAME = Apertium
Apertium_OBJC_FILES = main.m ApertiumServer.m ApertiumController.m SourceLanguagePopup.m ApertiumInfo.m ApertiumTranslator.m
Apertium_LDFLAGS += -lDBusKit
Apertium_RESOURCE_FILES = \
  LanguagePanel.gorm
include $(GNUSTEP_MAKEFILES)/service.make
