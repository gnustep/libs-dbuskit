include $(GNUSTEP_MAKEFILES)/common.make
SERVICE_NAME = Apertium
Apertium_OBJC_FILES = main.m \
	ApertiumController.m \
	ApertiumInfo.m \
	ApertiumServer.m \
	ApertiumTranslator.m \
	ApertiumUtilityPanel.m \
	SourceLanguagePopup.m
Apertium_LDFLAGS += -lDBusKit
Apertium_RESOURCE_FILES = \
  LanguagePanel.gorm
include $(GNUSTEP_MAKEFILES)/service.make
