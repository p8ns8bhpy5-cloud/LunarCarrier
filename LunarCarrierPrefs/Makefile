include ../LunarCarrier_Build.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LunarCarrierPrefs
LunarCarrierPrefs_FILES = $(wildcard *.m)
LunarCarrierPrefs_CFLAGS = -fobjc-arc
LunarCarrierPrefs_FRAMEWORKS = UIKit Foundation
LunarCarrierPrefs_PRIVATE_FRAMEWORKS = Preferences
LunarCarrierPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
