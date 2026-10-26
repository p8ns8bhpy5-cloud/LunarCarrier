DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

include LunarCarrier_Build.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LunarCarrier
LunarCarrier_FILES = $(wildcard Hooks/*.xm Sources/*.m)
LunarCarrier_CFLAGS = -fobjc-arc -I./Headers -I./Sources -Wno-deprecated-declarations -w
LunarCarrier_FRAMEWORKS = UIKit Foundation CoreFoundation
LunarCarrier_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += LunarCarrierPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
