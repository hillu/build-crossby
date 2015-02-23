include $(BUILD_CROSSBY_PROJECT_FILE)
$(foreach pkg,$(PACKAGES),$(eval include package/$(pkg).mk))

# GENERIC TOP-LEVEL TEMPLATES
# ---------------------------

define GEN_INDEP_TEMPLATE
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

define GEN_ARCH_TEMPLATE
$(if $(or $(if $($(1)_ARCHS),,what),$(and $($(1)_ARCHS),$(findstring $(2),$($(1)_ARCHS)))),$(call _GEN_ARCH_TEMPLATE,$(1),$(2)))
endef

define _GEN_ARCH_TEMPLATE
# UNPACK PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_UNPACK,$(1),$(2))

build/$(1)/$(2)/.unpack-stamp: $($(1)_TARBALL)
unpack/$(1)/$(2): build/$(1)/$(2)/.unpack-stamp
unpack/$(1): unpack/$(1)/$(2)
unpack: unpack/$(1)/$(2)
.PHONY: unpack/$(1) unpack/$(1)/$(2)
# END UNPACK PACKAGE=$(1) ARCH=$(2)

# DEPENDENCIES $(1): $($(1)_DEPENDS)
$(foreach dep,$($(1)_DEPENDS),build/$(1)/$(2)/.build-stamp: build/$(dep)/$(2)/.install-stamp)
# END DEPENDENCIES

# BUILD PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_BUILD,$(1),$(2))

build/$(1)/$(2)/.build-stamp: build/$(1)/$(2)/.unpack-stamp
build/$(1)/$(2): build/$(1)/$(2)/.build-stamp
build/$(1): build/$(1)/$(2)
build: build/$(1)/$(2)
.PHONY: build/$(1) build/$(1)/$(2)
# END BUILD PACKAGE=$(1) ARCH=$(2)

# INSTALL PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_INSTALL,$(1),$(2))

build/$(1)/$(2)/.install-stamp: build/$(1)/$(2)/.build-stamp
install/$(1)/$(2): build/$(1)/$(2)/.install-stamp
install/$(1): install/$(1)/$(2)
install: install/$(1)/$(2)
.PHONY: install/$(1)/$(2)
# END INSTALL PACKAGE=$(1) ARCH=$(2)

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

.PHONY: download unpack build install clean bleach dump

# BUILD SYSTEM-SPECIFIC TEMPLATES
# -------------------------------

define generic_UNPACK
# generic_UNPACK PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.unpack-stamp:
	mkdir -p $$(dir $$@)
	tar --strip=1 -xzf $($(1)_TARBALL) -C $$(dir $$@)
	for patch in $(wildcard patches/$(1)/$($(1)_VERSION)/*.patch); do \
		patch -d $$(dir $$@) -p1 < $$$$patch ; \
	done
ifneq ($($(1)_POSTUNPACK),)
	cd $$(dir $$@) && $($(1)_POSTUNPACK)
endif
	touch $$@
# END generic_UNPACK PACKAGE=$(1) ARCH=$(2)
endef

# Autoconf
autoconf_UNPACK = $(generic_UNPACK)
define autoconf_BUILD
# autoconf_BUILD PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.build-stamp:
	cd $$(dir $$@) && ./configure --host=$(2) \
		CFLAGS="$(strip $(if $(findstring x86_64,$(2)),-m64,-m32) $($(1)_CFLAGS) $($(1)_$(2)_CFLAGS))" \
		$($(1)_BUILDFLAGS) $($(1)_$(2)_BUILDFLAGS) \
		--prefix=$(PWD)/target \
		--includedir='$$$$(prefix)/include' \
		--mandir='$$$$(prefix)/share/man' \
		--infodir='$$$$(prefix)/share/info' \
		--sysconfdir='$$$$(prefix)/etc' \
		--libdir='$$$${prefix}/lib/$(2)' \
		--libexecdir='$$$${prefix}/lib/$(2)' \
		--bindir='$$$${prefix}/bin/$(2)' \
		--sbindir='$$$${prefix}/sbin/$(2)'

	$(MAKE) -C $$(dir $$@)
	touch $$@
# END autoconf_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define autoconf_INSTALL
# autoconf_INSTALL PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.install-stamp:
	$(MAKE) -C build/$(1)/$(2)/ install prefix=$(PWD)/target
	touch $$@
# END autoconf_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# Golang
GOOS=$(strip \
    $(if $(filter %-linux-gnu,$(1)),linux,\
        $(if $(filter %-w64-% %-mingw32,$(1)),windows,\
            $(error GOOS: unrecognized architecture $(1)))))

GOARCH=$(strip \
    $(if $(filter x86_64-%,$(1)),amd64,\
        $(if $(filter i386-% i686-%,$(1)),386,\
            $(error GOARCH: unrecognized architecture $(1)))))

CGO_CC=$(strip \
    $(if $(filter %w64-mingw32,$(1)),\
        $(1)-gcc,gcc))

define go_UNPACK
# go_UNPACK PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.unpack-stamp:
	mkdir -p build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	tar --strip=1 -xzf $($(1)_TARBALL) -C build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	for patch in $(wildcard patches/$(1)/$($(1)_VERSION)/*.patch); do \
		patch -d build/$(1)/$(2)/src/$($(1)_NAMESPACE) -p1 < $$$$patch ; \
	done
	touch $$@
# END go_UNPACK PACKAGE=$(1) ARCH=$(2)
endef
define go_BUILD
# go_BUILD PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.build-stamp:
	cd build/$(1)/$(2)/ && \
		CGO_CFLAGS=-I$(PWD)/target/include \
		CGO_LDFLAGS=-L$(PWD)/target/lib/$(2) \
		GOPATH=$(PWD)/build/$(1)/$(2) \
		GOOS=$(call GOOS,$(2)) GOARCH=$(call GOARCH,$(2)) \
		CC=$(call CGO_CC,$(2)) \
		CGO_ENABLED=1 \
		go install -x --ldflags '-extldflags "-static"' $($(1)_NAMESPACE)
	touch $$@
# END go_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define go_INSTALL
# go_INSTALL PACKAGE=$(1) ARCH=$(2)
build/$(1)/$(2)/.install-stamp:
	mkdir -p $(PWD)/target/lib/go
	cp -urt $(PWD)/target/lib/go/ build/$(1)/$(2)/pkg build/$(1)/$(2)/src
	touch $$@
# END go_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# END OF BUILD SYSTEM-SPECIFIC TEMPLATES

# This puts everything together:
$(foreach pkg,$(PACKAGES),\
	$(eval $(call GEN_INDEP_TEMPLATE,$(pkg))) \
	$(foreach arch,$(ARCHS),\
		$(eval $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))))

# For debugging purposes:
define DUMPHEADER
# AUTOMATICALLY GENERATED RULES
# =============================
endef
dump:
	$(info $(DUMPHEADER))
	$(foreach pkg,$(PACKAGES),\
		$(info $(call GEN_INDEP_TEMPLATE,$(pkg))) \
		$(foreach arch,$(ARCHS),\
			$(info $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))))
	@true
