# build-crossby.
#
# Copyright (C) 2015, 2016  Hilko Bengen <bengen@hilluzination.de>
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
BC_ARCHS    ?= x86_64-linux-musl i386-linux-musl i686-w64-mingw32 x86_64-w64-mingw32
# FIXME: Is there a better way?
BC_PRIMARY_ARCH ?= $(shell gcc -print-multiarch)
BC_PACKAGES ?= $(patsubst %.mk,%,$(notdir $(wildcard $(BC_ROOT)/package/*.mk)))
BC_IMPORT   ?=
GOROOT      ?= $(shell go env GOROOT)

-include $(BC_ROOT)/$(BC_PROJECT).mk
$(foreach pkg,$(BC_PACKAGES),$(eval include $(BC_ROOT)/package/$(pkg).mk))

# CONVENIENCE FUNCTIONS
# ---------------------
# BC_BUILDDIR PKG,ARCH
BC_BUILDDIR = $(BC_ROOT)/build/$(2)/$(1)-$($(1)_VERSION)
# BC_GOAL STAGE,PKG,ARCH
BC_GOAL = $(BC_ROOT)/stamps/$(1)-$(2)-$($(2)_VERSION)-$(3)

# BC_CC ARCH; BC_CXX ARCH: Determine compiler to use -- not at
# template build time, but at execution time.
BC_CC   = $$(or $$(shell PATH=$$(PATH) which $(1)-gcc),gcc)
BC_CXX  = $$(or $$(shell PATH=$$(PATH) which $(1)-g++),g++)

# GENERIC TOP-LEVEL TEMPLATES
# ---------------------------

define GEN_INDEP_TEMPLATE
# DOWNLOAD $(1)
$(1)_SUFFIX := $(or $($(1)_SUFFIX),$(foreach suffix,.tar.xz .tar.bz2 .tar.gz,\
	$(if $(filter %$(suffix),$($(1)_URL)),$(suffix))))
$(1)_TARBALL = $(BC_ROOT)/cache/$(1)-$$($(1)_VERSION)$$($(1)_SUFFIX)
$(1)_TARBALL_LOCAL = $(BC_ROOT)/tarballs/$(1)-$$($(1)_VERSION)$$($(1)_SUFFIX)
$$($(1)_TARBALL):
	mkdir -p $$(dir $$@)
	if test -e $$($(1)_TARBALL_LOCAL); \
	then \
		cp -u $$($(1)_TARBALL_LOCAL) $$($(1)_TARBALL); \
	else \
		wget -c -O $$@.t $($(1)_URL) && mv $$@.t $$@; \
	fi

BC/download/$(1): $$($(1)_TARBALL)
BC/download: BC/download/$(1)
.PHONY: BC/download/$(1)
# END DOWNLOAD $(1)
endef

define GEN_ARCH_TEMPLATE
$(if $(or
	$(if $($(1)_ARCHS),,empty),
	$(and
		$($(1)_ARCHS),
		$(findstring $(2),$($(1)_ARCHS)))),
$(call _GEN_ARCH_TEMPLATE,$(1),$(2)))
endef

define _GEN_ARCH_TEMPLATE
# UNPACK PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,unpack,$(1),$(2)): $($(1)_TARBALL)
$(call $($(1)_BUILDSYSTEM)_UNPACK,$(1),$(2))

BC/unpack/$(1)/$(2): $(call BC_GOAL,unpack,$(1),$(2))
BC/unpack/$(1): BC/unpack/$(1)/$(2)
BC/unpack: BC/unpack/$(1)/$(2)
.PHONY: BC/unpack/$(1) BC/unpack/$(1)/$(2)
# END UNPACK PACKAGE=$(1) ARCH=$(2)

$(if $(or $($(1)_DEPENDS),$($(1)_$(2)_DEPENDS)),
# DEPENDENCIES $(1) $(2) $($(1)_DEPENDS)
$(foreach dep,$($(1)_DEPENDS) $($(1)_$(2)_DEPENDS),
$(call BC_GOAL,build,$(1),$(2)): $(call BC_GOAL,install,$(dep),$(2))
)
# END DEPENDENCIES
,
# NO DEPENDENCIES FOR $(1) $(2)
)

# BUILD PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,build,$(1),$(2)): $(call BC_GOAL,unpack,$(1),$(2))
$(call BC_GOAL,build,$(1),$(2)): export PATH=$(PATH):$(BC_ROOT)/target/bin
$(call $($(1)_BUILDSYSTEM)_BUILD,$(1),$(2))

BC/build/$(1)/$(2): $(call BC_GOAL,build,$(1),$(2))
BC/build/$(1): BC/build/$(1)/$(2)
BC/build: BC/build/$(1)/$(2)
.PHONY: BC/build/$(1) BC/build/$(1)/$(2)
# END BUILD PACKAGE=$(1) ARCH=$(2)

# INSTALL PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,install,$(1),$(2)): $(call BC_GOAL,build,$(1),$(2))
$(call BC_GOAL,install,$(1),$(2)): export PATH=$(PATH):$(BC_ROOT)/target/bin
$(call $($(1)_BUILDSYSTEM)_INSTALL,$(1),$(2))

BC/install/$(1)/$(2): $(call BC_GOAL,install,$(1),$(2))
BC/install/$(1): BC/install/$(1)/$(2)
BC/install: BC/install/$(1)/$(2)
BC/clear-install/$(1)/$(2):
	rm -f $(call BC_GOAL,install,$(1),$(2))
BC/clear-install: BC/clear-install/$(1)/$(2)
.PHONY: BC/install/$(1)/$(2) BC/clear-install/$(1)/$(2)
# END INSTALL PACKAGE=$(1) ARCH=$(2)

# CLEAN PACKAGE=$(1) ARCH=$(2)
BC/clean/$(1)/$(2):
	rm -rf $(call BC_BUILDDIR,$(1),$(2))/ \
		$(call BC_GOAL,build,$(1),$(2)) \
		$(call BC_GOAL,unpack,$(1),$(2))

BC/clean/$(1): BC/clean/$(1)/$(2)
BC/clean: BC/clean/$(1)/$(2)
.PHONY: BC/clean/$(1)/$(2)
# END CLEAN PACKAGE=$(1) ARCH=$(2)

endef

BC/install:
	for binary in $(BC_ROOT)/target/bin/$(BC_PRIMARY_ARCH)/*; do \
		test -f $$binary && \
		cp -sft $(BC_ROOT)/target/bin $$binary || \
		true; \
	done
BC/clear-install:
	rm -rf $(BC_ROOT)/target $(BC_ROOT)/stamps/install-*
BC/bleach: BC/clean BC/clear-install
	rm -rf $(BC_ROOT)/cache

.PHONY: BC/download BC/unpack BC/build BC/install BC/clear-install BC/clean BC/bleach BC/dump

# BUILD SYSTEM-SPECIFIC TEMPLATES
# -------------------------------

define generic_UNPACK
# generic_UNPACK PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,unpack,$(1),$(2)):
	mkdir -p $(call BC_BUILDDIR,$(1),$(2))
ifeq ($($(1)_SUFFIX),.tar.gz)
	tar --strip=1 -xzf $($(1)_TARBALL) -C $(call BC_BUILDDIR,$(1),$(2))
else ifeq ($($(1)_SUFFIX),.tar.bz2)
	tar --strip=1 -xjf $($(1)_TARBALL) -C $(call BC_BUILDDIR,$(1),$(2))
else ifeq ($($(1)_SUFFIX),.tar.xz)
	tar --strip=1 -xJf $($(1)_TARBALL) -C $(call BC_BUILDDIR,$(1),$(2))
else
	$$(error Could not determine archive format from URL <$($(1)_URL)>.)
endif
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$(1)/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$(1)/$($(1)_VERSION)/*.patch)),\
		patch -d $(call BC_BUILDDIR,$(1),$(2)) -p1 < $(patch) && ) true
ifneq ($($(1)_POSTUNPACK),)
	cd $(call BC_BUILDDIR,$(1),$(2)) && $($(1)_POSTUNPACK)
endif
	mkdir -p $$(@D) && touch $$@
# END generic_UNPACK PACKAGE=$(1) ARCH=$(2)
endef

# Make
make_UNPACK = $(generic_UNPACK)
define make_BUILD
# make_BUILD PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,build,$(1),$(2)):
	$(foreach tgt,$(or $(strip $($(1)_$(2)_BUILDTARGETS) $($(1)_BUILDTARGETS)),all),\
	make -C $(call BC_BUILDDIR,$(1),$(2))/ \
		$($(1)_BUILDFLAGS) $($(1)_$(2)_BUILDFLAGS) \
		CC=$(or $($(1)_$(2)_CC),$($(1)_CC),$$(call BC_CC,$(2))) \
		CXX=$(or $($(1)_$(2)_CXX),$($(1)_CXX),$$(call BC_CXX,$(2))) \
		$(tgt) && ) true
	mkdir -p $$(@D) && touch $$@
# END autoconf_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define make_INSTALL
# make_INSTALL PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,install,$(1),$(2)):
	$(foreach tgt,$(or $(strip $($(1)_$(2)_INSTALLTARGETS) $($(1)_INSTALLTARGETS)),install),\
		$(MAKE) -C $(call BC_BUILDDIR,$(1),$(2))/ \
			$($(1)_INSTALLFLAGS) $($(1)_$(2)_INSTALLFLAGS) \
			$(tgt))
ifneq ($($(1)_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$(1),$(2)) && $($(1)_POSTINSTALL)
endif
ifneq ($($(1)_$(2)_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$(1),$(2)) && $($(1)_$(2)_POSTINSTALL)
endif
	mkdir -p $$(@D) && touch $$@
# END make_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# Autoconf
autoconf_UNPACK = $(generic_UNPACK)
define autoconf_BUILD
# autoconf_BUILD PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,build,$(1),$(2)):
	cd $(call BC_BUILDDIR,$(1),$(2)) && ./configure \
		--build=$(BC_PRIMARY_ARCH) \
		--host=$(2) \
		CC=$(or $($(1)_$(2)_CC),$($(1)_CC),$$(call BC_CC,$(2))) \
		CXX=$(or $($(1)_$(2)_CXX),$($(1)_CXX),$$(call BC_CXX,$(2))) \
		CPPFLAGS="-I$(BC_ROOT)/target/include/$(2)" \
		CFLAGS="$(strip $(if $(findstring x86_64,$(2)),-m64,-m32) $($(1)_CFLAGS) $($(1)_$(2)_CFLAGS))" \
		PKG_CONFIG_PATH=$(BC_ROOT)/target/lib/$(2)/pkgconfig \
		$($(1)_CONFIGFLAGS) $($(1)_$(2)_CONFIGDFLAGS) \
		--prefix=$(BC_ROOT)/target \
		--includedir='$$$$(prefix)/include/$(2)' \
		--mandir='$$$$(prefix)/share/man' \
		--infodir='$$$$(prefix)/share/info' \
		--sysconfdir='$$$$(prefix)/etc' \
		--libdir='$$$${prefix}/lib/$(2)' \
		--libexecdir='$$$${prefix}/lib/$(2)' \
		--bindir='$$$${prefix}/bin/$(2)' \
		--sbindir='$$$${prefix}/sbin/$(2)'

	$(MAKE) -C $(call BC_BUILDDIR,$(1),$(2)) $($(1)_BUILDFLAGS) $($(1)_$(2)_BUILDFLAGS)
	mkdir -p $$(@D) && touch $$@
# END autoconf_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define autoconf_INSTALL
# autoconf_INSTALL PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,install,$(1),$(2)):
	$(MAKE) -C $(call BC_BUILDDIR,$(1),$(2))/ install prefix=$(BC_ROOT)/target
ifneq ($($(1)_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$(1),$(2)) && $($(1)_POSTINSTALL)
endif
ifneq ($($(1)_$(2)_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$(1),$(2)) && $($(1)_$(2)_POSTINSTALL)
endif
	mkdir -p $$(@D) && touch $$@
# END autoconf_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# Golang
GOOS=$(strip \
    $(if $(findstring -linux-,$(1)),linux,\
        $(if $(filter %-w64-% %-mingw32,$(1)),windows,\
            $(error GOOS: unrecognized architecture $(1)))))

GOARCH=$(strip \
    $(if $(filter x86_64-%,$(1)),amd64,\
        $(if $(filter i386-% i686-%,$(1)),386,\
            $(error GOARCH: unrecognized architecture $(1)))))

define go_UNPACK
# go_UNPACK PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,unpack,$(1),$(2)):
	mkdir -p $(call BC_BUILDDIR,$(1),$(2))/src/$($(1)_NAMESPACE)
	tar --strip=1 -xzf $($(1)_TARBALL) -C $(call BC_BUILDDIR,$(1),$(2))/src/$($(1)_NAMESPACE)
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$(1)/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$(1)/$($(1)_VERSION)/*.patch)),\
		patch -d $(call BC_BUILDDIR,$(1),$(2))/src/$($(1)_NAMESPACE) -p1 < $(patch))
	mkdir -p $$(@D) && touch $$@
# END go_UNPACK PACKAGE=$(1) ARCH=$(2)
endef
define go_BUILD
# go_BUILD PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,build,$(1),$(2)): export CGO_CFLAGS=-I$(BC_ROOT)/target/include/$(2)
$(call BC_GOAL,build,$(1),$(2)): export CGO_CFLAGS+=$($(1)_CGO_CFLAGS)
$(call BC_GOAL,build,$(1),$(2)): export CGO_CFLAGS+=$($(1)_$(2)_CGO_CFLAGS)
$(call BC_GOAL,build,$(1),$(2)): export CGO_LDFLAGS=-L$(BC_ROOT)/target/lib/$(2)
$(call BC_GOAL,build,$(1),$(2)): export CGO_LDFLAGS+=$($(1)_CGO_LDFLAGS)
$(call BC_GOAL,build,$(1),$(2)): export CGO_LDFLAGS+=$($(1)_$(2)_CGO_LDFLAGS)
$(call BC_GOAL,build,$(1),$(2)): export GOPATH=$(call BC_BUILDDIR,$(1),$(2)):$(BC_ROOT)/target/lib/$(2)/go
$(call BC_GOAL,build,$(1),$(2)): export GOOS=$(call GOOS,$(2))
$(call BC_GOAL,build,$(1),$(2)): export GOARCH=$(call GOARCH,$(2))
$(call BC_GOAL,build,$(1),$(2)): export CC=$(call BC_CC,$(2))
$(call BC_GOAL,build,$(1),$(2)): export CGO_ENABLED=1
$(call BC_GOAL,build,$(1),$(2)):
	cd $(call BC_BUILDDIR,$(1),$(2))/ && \
		$(GOROOT)/bin/go install -x --ldflags '-extldflags "-static"' $($(1)_NAMESPACE)...
	mkdir -p $$(@D) && touch $$@
# END go_BUILD PACKAGE=$(1) ARCH=$(2)
endef
define go_INSTALL
# go_INSTALL PACKAGE=$(1) ARCH=$(2)
$(call BC_GOAL,install,$(1),$(2)):
	mkdir -p $(BC_ROOT)/target/lib/$(2)/go
	cp -fprt $(BC_ROOT)/target/lib/$(2)/go/ $(call BC_BUILDDIR,$(1),$(2))/pkg $(call BC_BUILDDIR,$(1),$(2))/src
	mkdir -p $(BC_ROOT)/target/bin/$(2)
# FIXME: Add a function to filter-out filenames
	$$(foreach binary,\
		$$(wildcard $(call BC_BUILDDIR,$(1),$(2))/bin/* \
			$(call BC_BUILDDIR,$(1),$(2))/bin/$(call GOOS,$(2))_$(call GOARCH,$(2)_)/*),\
		if test -f $$(binary); then \
			install -m755 $$(binary) $(BC_ROOT)/target/bin/$(2);\
		fi;)
	mkdir -p $$(@D) && touch $$@
# END go_INSTALL PACKAGE=$(1) ARCH=$(2)
endef

# END OF BUILD SYSTEM-SPECIFIC TEMPLATES

# This puts everything together:
$(foreach pkg,$(BC_PACKAGES),\
	$(eval $(call GEN_INDEP_TEMPLATE,$(pkg))) \
	$(if $($(pkg)_ARCHS),\
		$(foreach arch,$(sort $($(pkg)_ARCHS)),\
			$(eval $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))),\
		$(foreach arch,$(sort $(BC_ARCHS)),\
			$(eval $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch))))))

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

.PHONY: BC/download-instructions

BC/download-instructions:
	$(info The following commands can be used to pre-download files needed in)
	$(info $(BC_ROOT)/cache :)
	$(foreach pkg,$(BC_PACKAGES),\
		$(info wget -O- $($(pkg)_URL) > $($(pkg)_TARBALL_LOCAL)))
	@true
