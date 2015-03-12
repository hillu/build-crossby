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
	$(info - clear-install: Remove target directory and .install-stamp files)
	$(info - bleach: Remove everything except the build scripts and configuration)
	$(info - dump:   Dump generated bits of this Makefile for debugging purposes)
	$(info )
	$(info Current configuration)
	$(info ---------------------)
	$(info BC_ROOT = $(BC_ROOT))
	$(info BC_PROJECT = $(BC_PROJECT) (File: $(BC_ROOT)/$(BC_PROJECT).mk))
	$(info BC_PACKAGES = $(BC_PACKAGES))
	$(info BC_ARCHS = $(BC_ARCHS))
	@true

.PHONY: help

BC_IMPORT = 1
include $(PWD)/build-crossby.mk
