include config.mk
include buildsys/*.mk
$(foreach pkg,$(PACKAGES),$(eval include package/$(pkg).mk))

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
	$(info Packages: $(PACKAGES))
	$(info Supported architectures:)
	$(info $(ARCHS))
	@true

COMMENT=\#
dump:
	$(info $(COMMENT) AUTOMATICALLY GENERATED CODE)
	$(info $(COMMENT) ----------------------------)
	$(foreach pkg,$(PACKAGES),\
		$(info $(call DOWNLOAD,$(pkg))) \
		$(foreach arch,$(ARCHS),\
			$(info $(call UNPACK,$(pkg),$(arch))) \
			$(info $(call BUILD,$(pkg),$(arch))) \
			$(info $(call INSTALL,$(pkg),$(arch))) \
			$(info $(call CLEAN,$(pkg),$(arch)))))
	@true

define DOWNLOAD
# DOWNLOAD $(1)
$(1)_TARBALL = cache/$(1)-$($(1)_VERSION)$($(1)_SUFFIX)
$$($(1)_TARBALL):
	mkdir -p cache
	wget -c -O $$@.t $($(1)_URL)
	mv $$@.t $$@

download/$(1): $$($(1)_TARBALL)
download: download/$(1)
.PHONY: download/$(1)
# END DOWNLOAD $(1)
endef

define UNPACK
# UNPACK PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_UNPACK,$(1),$(2))

build/$(1)/$(2)/.unpack-stamp: $($(1)_TARBALL)
unpack/$(1)/$(2): build/$(1)/$(2)/.unpack-stamp
unpack/$(1): unpack/$(1)/$(2)
unpack: unpack/$(1)/$(2)
.PHONY: unpack/$(1) unpack/$(1)/$(2)
# END UNPACK PACKAGE=$(1) ARCH=$(2)
endef

define BUILD
# BUILD PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_BUILD,$(1),$(2))

# DEPENDENCIES $(1): $($(1)_DEPENDS)
$(foreach dep,$($(1)_DEPENDS),build/$(1)/$(2)/.build-stamp: build/$(dep)/$(2)/.install-stamp)
# END DEPENDENCIES
build/$(1)/$(2)/.build-stamp: build/$(1)/$(2)/.unpack-stamp
build/$(1)/$(2): build/$(1)/$(2)/.build-stamp
build/$(1): build/$(1)/$(2)
build: build/$(1)/$(2)
.PHONY: build/$(1) build/$(1)/$(2)
# END BUILD PACKAGE=$(1) ARCH=$(2)
endef

define INSTALL
# INSTALL PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_INSTALL,$(1),$(2))

build/$(1)/$(2)/.install-stamp: build/$(1)/$(2)/.build-stamp
install/$(1)/$(2): build/$(1)/$(2)/.install-stamp
install/$(1): install/$(1)/$(2)
install: install/$(1)/$(2)
.PHONY: install/$(1)/$(2)
# END INSTALL PACKAGE=$(1) ARCH=$(2)
endef

define CLEAN
# CLEAN PACKAGE=$(1) ARCH=$(2)
clean/$(1)/$(2):
	rm -rf build/$(1)/$(2)/

clean/$(1): clean/$(1)/$(2)
clean: clean/$(1)/$(2)
.PHONY: clean/$(1)/$(2)
# END CLEAN PACKAGE=$(1) ARCH=$(2)
endef

bleach: clean
	rm -rf cache target

.PHONY: help download unpack build install clean bleach dump

$(foreach pkg,$(PACKAGES),\
	$(eval $(call DOWNLOAD,$(pkg))) \
	$(foreach arch,$(ARCHS),\
		$(eval $(call UNPACK,$(pkg),$(arch))) \
		$(eval $(call BUILD,$(pkg),$(arch))) \
		$(eval $(call INSTALL,$(pkg),$(arch))) \
		$(eval $(call CLEAN,$(pkg),$(arch)))))
