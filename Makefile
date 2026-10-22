TARGET := iphone:clang:latest:16.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = SiriGemini
SiriGemini_FILES = Tweak.x GeminiClient.m GeminiOverlay.m
SiriGemini_CFLAGS = -fobjc-arc
SiriGemini_FRAMEWORKS = UIKit AVFoundation
include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp prefs.plist $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceLoader/Preferences/SiriGemini.plist$(ECHO_END)
