ARCHS = armv7
TARGET = iphone:clang:9.3:8.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AmbientMusic

AmbientMusic_FILES = main.m
AmbientMusic_FRAMEWORKS = UIKit MediaPlayer AVFoundation CoreGraphics
AmbientMusic_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AmbientMusic_INSTALL_PATH = /Applications
AmbientMusic_BUNDLE_IDENTIFIER = com.jzh8y7svw5.ambientmusic
AmbientMusic_INFO_PLIST = Resources/Info.plist
AmbientMusic_USE_MODULES = 0

include $(THEOS_MAKE_PATH)/application.mk
