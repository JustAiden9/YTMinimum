DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
PACKAGE_VERSION = 1.0.0
TARGET := iphone:clang:16.5:16.0
THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTMinimum
YTMinimum_FILES = $(wildcard Sources/*.xm Sources/*.m)
YTMinimum_CFLAGS = -fobjc-arc -fblocks -DPACKAGE_VERSION=\"$(PACKAGE_VERSION)\"
YTMinimum_FRAMEWORKS = UIKit Foundation Security MediaPlayer QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
