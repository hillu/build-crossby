# build-crossby.
#
# Copyright (C) 2015  Hilko Bengen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# DEFAULT VALUES
# --------------

BC_ROOT     ?= $(PWD)
BC_PROJECT  ?= default
BC_ARCHS    ?= x86_64-linux-gnu i386-linux-gnu i686-w64-mingw32 x86_64-w64-mingw32
# FIXME: Is there a better way?
BC_PRIMARY_ARCH ?= $(shell gcc -print-multiarch)
BC_PACKAGES ?= $(patsubst %.mk,%,$(notdir $(wildcard $(BC_ROOT)/package/*.mk)))
BC_IMPORT   ?=

-include $(BC_ROOT)/$(BC_PROJECT).mk
$(foreach pkg,$(BC_PACKAGES),$(eval include $(BC_ROOT)/package/$(pkg).mk))

# GENERIC TOP-LEVEL TEMPLATES
# ---------------------------

define GEN_INDEP_TEMPLATE
# DOWNLOAD $(1)
$(1)_TARBALL = $(BC_ROOT)/cache/$(1)-$($(1)_VERSION)$($(1)_SUFFIX)
$$($(1)_TARBALL):
	mkdir -p $$(dir $$@)
	wget -c -O $$@.t $($(1)_URL)
	mv $$@.t $$@

BC/download/$(1): $$($(1)_TARBALL)
BC/download: BC/download/$(1)
.PHONY: BC/download/$(1)
# END DOWNLOAD $(1)

endef

define GEN_ARCH_TEMPLATE
$(if $(or $(if $($(1)_ARCHS),,what),$(and $($(1)_ARCHS),$(findstring $(2),$($(1)_ARCHS)))),$(call _GEN_ARCH_TEMPLATE,$(1),$(2)))
endef

define _GEN_ARCH_TEMPLATE
# UNPACK PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_UNPACK,$(1),$(2))

$(BC_ROOT)/build/$(1)/$(2)/.unpack-stamp: $($(1)_TARBALL)
BC/unpack/$(1)/$(2): $(BC_ROOT)/build/$(1)/$(2)/.unpack-stamp
BC/unpack/$(1): BC/unpack/$(1)/$(2)
BC/unpack: BC/unpack/$(1)/$(2)
.PHONY: BC/unpack/$(1) BC/unpack/$(1)/$(2)
# END UNPACK PACKAGE=$(1) ARCH=$(2)

# DEPENDENCIES $(1) $($(1)_DEPENDS)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: $(patsubst %,$(BC_ROOT)/build/%/$(2)/.install-stamp,$($(1)_DEPENDS))
# END DEPENDENCIES

# BUILD PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_BUILD,$(1),$(2))

$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export PATH=$(PATH):$(BC_ROOT)/target/bin
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: $(BC_ROOT)/build/$(1)/$(2)/.unpack-stamp
BC/build/$(1)/$(2): $(BC_ROOT)/build/$(1)/$(2)/.build-stamp
BC/build/$(1): BC/build/$(1)/$(2)
BC/build: BC/build/$(1)/$(2)
.PHONY: BC/build/$(1) BC/build/$(1)/$(2)
# END BUILD PACKAGE=$(1) ARCH=$(2)

# INSTALL PACKAGE=$(1) ARCH=$(2)
$(call $($(1)_BUILDSYSTEM)_INSTALL,$(1),$(2))

$(BC_ROOT)/build/$(1)/$(2)/.install-stamp: export PATH=$(PATH):$(BC_ROOT)/target/bin
$(BC_ROOT)/build/$(1)/$(2)/.install-stamp: $(BC_ROOT)/build/$(1)/$(2)/.build-stamp
BC/install/$(1)/$(2): $(BC_ROOT)/build/$(1)/$(2)/.install-stamp
BC/install/$(1): BC/install/$(1)/$(2)
BC/install: BC/install/$(1)/$(2)
BC/clear-install/$(1)/$(2):
	rm -f $(BC_ROOT)/build/$(1)/$(2)/.install-stamp
BC/clear-install: BC/clear-install/$(1)/$(2)
.PHONY: BC/install/$(1)/$(2) BC/clear-install/$(1)/$(2)
# END INSTALL PACKAGE=$(1) ARCH=$(2)

# CLEAN PACKAGE=$(1) ARCH=$(2)
BC/clean/$(1)/$(2):
	rm -rf $(BC_ROOT)/build/$(1)/$(2)/

BC/clean/$(1): BC/clean/$(1)/$(2)
BC/clean: BC/clean/$(1)/$(2)
.PHONY: BC/clean/$(1)/$(2)
# END CLEAN PACKAGE=$(1) ARCH=$(2)

endef

BC/install:
	for binary in $(BC_ROOT)/target/bin/$(BC_PRIMARY_ARCH)/*; do \
		test -f $$binary && cp -sft $(BC_ROOT)/target/bin $$binary; \
	done
BC/clear-install:
	rm -rf $(BC_ROOT)/target
BC/bleach: BC/clean BC/clear-install
	rm -rf $(BC_ROOT)/cache

.PHONY: BC/download BC/unpack BC/build BC/install BC/clear-install BC/clean BC/bleach BC/dump

# BUILD SYSTEM-SPECIFIC TEMPLATES
# -------------------------------

define generic_UNPACK
# generic_UNPACK PACKAGE=$(1) ARCH=$(2)
$(BC_ROOT)/build/$(1)/$(2)/.unpack-stamp:
	mkdir -p $$(dir $$@)
	tar --strip=1 -xzf $($(1)_TARBALL) -C $$(dir $$@)
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$(1)/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$(1)/$($(1)_VERSION)/*.patch)),\
		patch -d $$(dir $$@) -p1 < $(patch))
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
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp:
	cd $$(dir $$@) && ./configure --host=$(2) \
		CPPFLAGS="-I$(BC_ROOT)/target/include/$(2)" \
		CFLAGS="$(strip $(if $(findstring x86_64,$(2)),-m64,-m32) $($(1)_CFLAGS) $($(1)_$(2)_CFLAGS))" \
		PKG_CONFIG_PATH=$(BC_ROOT)/target/lib/$(2)/pkgconfig \
		$($(1)_BUILDFLAGS) $($(1)_$(2)_BUILDFLAGS) \
		--prefix=$(BC_ROOT)/target \
		--includedir='$$$$(prefix)/include/$(2)' \
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
$(BC_ROOT)/build/$(1)/$(2)/.install-stamp:
	$(MAKE) -C $(BC_ROOT)/build/$(1)/$(2)/ install prefix=$(BC_ROOT)/target
ifneq ($($(1)_POSTINSTALL),)
	cd $$(dir $$@) && $($(1)_POSTINSTALL)
endif
ifneq ($($(1)_$(2)_POSTINSTALL),)
	cd $$(dir $$@) && $($(1)_$(2)_POSTINSTALL)
endif
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
$(BC_ROOT)/build/$(1)/$(2)/.unpack-stamp:
	mkdir -p $(BC_ROOT)/build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	tar --strip=1 -xzf $($(1)_TARBALL) -C $(BC_ROOT)/build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$(1)/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$(1)/$($(1)_VERSION)/*.patch)),\
		patch -d $(BC_ROOT)/build/$(1)/$(2)/src/$($(1)_NAMESPACE) -p1 < $(patch))
	touch $$@
# END go_UNPACK PACKAGE=$(1) ARCH=$(2)
endef
define go_BUILD
# go_BUILD PACKAGE=$(1) ARCH=$(2)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_CFLAGS=-I$(BC_ROOT)/target/include
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_CFLAGS+=$($(1)_CGO_CFLAGS)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_CFLAGS+=$($(1)_$(2)_CGO_CFLAGS)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_LDFLAGS=-L$(BC_ROOT)/target/lib/$(2)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_LDFLAGS+=$($(1)_CGO_LDFLAGS)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_LDFLAGS+=$($(1)_$(2)_CGO_LDFLAGS)
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export GOPATH=$(BC_ROOT)/build/$(1)/$(2):$(BC_ROOT)/target/lib/go
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export GOOS=$(call GOOS,$(2))
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export GOARCH=$(call GOARCH,$(2))
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CC=$(call CGO_CC,$(2))
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp: export CGO_ENABLED=1
$(BC_ROOT)/build/$(1)/$(2)/.build-stamp:
	cd $(BC_ROOT)/build/$(1)/$(2)/ && \
		go install -x --ldflags '-extldflags "-static"' $($(1)_NAMESPACE)...
	touch $$@
# END go_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define go_INSTALL
# go_INSTALL PACKAGE=$(1) ARCH=$(2)
$(BC_ROOT)/build/$(1)/$(2)/.install-stamp:
	mkdir -p $(BC_ROOT)/target/lib/go
	cp -furt $(BC_ROOT)/target/lib/go/ $(BC_ROOT)/build/$(1)/$(2)/pkg $(BC_ROOT)/build/$(1)/$(2)/src
	mkdir -p $(BC_ROOT)/target/bin/$(2)
# FIXME: Add a function to filter-out filenames
	$$(foreach binary,\
		$$(wildcard $(BC_ROOT)/build/$(1)/$(2)/bin/* \
			$(BC_ROOT)/build/$(1)/$(2)/bin/$(call GOOS,$(2))_$(call GOARCH,$(2)_)/*),\
		if test -f $$(binary); then \
			install -m755 $$(binary) $(BC_ROOT)/target/bin/$(2);\
		fi;)
	touch $$@
# END go_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# END OF BUILD SYSTEM-SPECIFIC TEMPLATES

# This puts everything together:
$(foreach pkg,$(BC_PACKAGES),\
	$(eval $(call GEN_INDEP_TEMPLATE,$(pkg))) \
	$(foreach arch,$(BC_ARCHS),\
		$(eval $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))))

# For debugging purposes:
define DUMPHEADER
# AUTOMATICALLY GENERATED RULES
# =============================
endef
BC/dump:
	$(info $(DUMPHEADER))
	$(foreach pkg,$(BC_PACKAGES),\
		$(info $(call GEN_INDEP_TEMPLATE,$(pkg))) \
		$(foreach arch,$(BC_ARCHS),\
			$(info $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))))
	@true

ifneq (,$(BC_IMPORT))
# Make targets from BC/ "namespace" accessible
$(foreach target,\
	download unpack build install clean clear-install bleach dump,\
	$(eval $(target): BC/$(target)))
$(foreach target,\
	download unpack build install clean,\
	$(foreach package,$(PACKAGES),\
		$(eval $(target)/$(package): BC/$(target)/$(package))))
$(foreach target,\
	build install clean,\
	$(foreach package,$(PACKAGES),\
		$(foreach arch,$(ARCHS),\
			$(eval $(target)/$(package)/$(arch): BC/$(target)/$(package)/$(arch)))))
endif
