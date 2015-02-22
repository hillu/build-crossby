help:
	$(info build crosby: Help)
	$(info ==================)
	$(info )
	$(info Targets)
	$(info -------)
	$(info - download, download/PACKAGE)
	$(info - unpack,   unpack/PACKAGE)
	$(info - build,    build/PACKAGE,   build/PACKAGE/ARCH)
	$(info - install,  install/PACKAGE, install/PACKAGE/ARCH)
	$(info - clean,    clean/PACKAGE,   clean/PACKAGE/ARCH)
	$(info - bleach: Remove everything except the build scripts and configuration)
	$(info - dump:   Dump generated bits of this Makefile for debugging purposes)
	$(info )
	$(info Current configuration)
	$(info ---------------------)
	$(info BUILD_CROSSBY_ROOT = $(BUILD_CROSSBY_ROOT))
	$(info BUILD_CROSSBY_PROJECT_FILE = $(BUILD_CROSSBY_PROJECT_FILE))
	$(info PACKAGES = $(PACKAGES))
	$(info ARCHS = $(ARCHS))
	@true

.PHONY: help

BUILD_CROSSBY_ROOT ?= $(PWD)
BUILD_CROSSBY_PROJECT_FILE ?= $(PWD)/default.mk
ARCHS ?= x86_64-linux-gnu i386-linux-gnu i686-w64-mingw32 x86_64-w64-mingw32
PACKAGES ?= $(patsubst %.mk,%,$(notdir $(wildcard package/*.mk)))

include $(BUILD_CROSSBY_ROOT)/build-crossby.mk


