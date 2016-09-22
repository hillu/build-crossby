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

$(if $(filter 4.%,$(MAKE_VERSION)),,$(error GNU make 4.0 or above is required))

# DEFAULT VALUES
# --------------

BC_ROOT     ?= $(PWD)
BC_PROJECT  ?= default
BC_ARCHS    ?= x86_64-linux-musl i386-linux-musl i686-w64-mingw32 x86_64-w64-mingw32
# FIXME: Is there a better way?
BC_PRIMARY_ARCH ?= $(shell gcc -dumpmachine)
# Packages that we want to be built. Does not need to include dependencies
BC_PACKAGES ?= $(patsubst %.mk,%,$(notdir $(wildcard $(BC_ROOT)/package/*.mk)))
BC_IMPORT   ?=
GOROOT      ?= $(shell go env GOROOT)

-include $(BC_ROOT)/$(BC_PROJECT).mk

$(foreach pkg,$(wildcard $(BC_ROOT)/package/*.mk),$(eval include $(pkg)))

# All available packages
# (The $(origin ...) call is used to filter out e.g. MAKE_VERSION.)
BC_AVAILABLE_PACKAGES := $(sort \
	$(BC_PACKAGES)\
	$(patsubst %_VERSION,%,\
		$(foreach var,$(filter %_VERSION,$(.VARIABLES)),\
			$(if $(findstring default,$(origin $(var))),,$(var))))\
	$(foreach pkg,$(filter %_DEPENDS,$(.VARIABLES)),$($(pkg))))

# CONVENIENCE FUNCTIONS
# ---------------------
# BC_BUILDDIR PKG,ARCH
BC_BUILDDIR = $(BC_ROOT)/build/$2/$1-$($1_VERSION)
# BC_GOAL STAGE,PKG,ARCH
BC_GOAL = $(BC_ROOT)/stamps/$1-$2-$($2_VERSION)-$3

# BC_CC ARCH; BC_CXX ARCH: Determine compiler to use -- not at
# template build time, but at execution time.
BC_CC   = $(or $(shell PATH=$(PATH) which $1-gcc),gcc)
BC_CXX  = $(or $(shell PATH=$(PATH) which $1-g++),g++)

# GENERIC TOP-LEVEL TEMPLATES
# ---------------------------

define GEN_INDEP_TEMPLATE
# DOWNLOAD $1
$1_SUFFIX := $(or $($1_SUFFIX),$(foreach suffix,.tar.xz .tar.bz2 .tar.gz,\
	$(if $(filter %$(suffix),$($1_URL)),$(suffix))))
$1_TARBALL = $(BC_ROOT)/cache/$1-$$($1_VERSION)$$($1_SUFFIX)
$1_TARBALL_LOCAL = $(BC_ROOT)/tarballs/$1-$$($1_VERSION)$$($1_SUFFIX)
$$($1_TARBALL):
	mkdir -p $$(dir $$@)
	if test -e $$($1_TARBALL_LOCAL); \
	then \
		cp -fp $$($1_TARBALL_LOCAL) $$($1_TARBALL); \
	else \
		wget -c -O $$@.t $($1_URL) && mv $$@.t $$@; \
	fi

BC/download/$1: $$($1_TARBALL)
$(if $(findstring $1,$(BC_PACKAGES)),BC/download: BC/download/$1)
.PHONY: BC/download/$1
# END DOWNLOAD $1
endef

define GEN_ARCH_TEMPLATE
$(if $(or
	$(if $($1_ARCHS),,empty),
	$(and
		$($1_ARCHS),
		$(findstring $2,$($1_ARCHS)))),
$(call _GEN_ARCH_TEMPLATE,$1,$2))
endef

define _GEN_ARCH_TEMPLATE
# UNPACK PACKAGE=$1 ARCH=$2
$(call BC_GOAL,unpack,$1,$2): $($1_TARBALL)
$(call $($1_BUILDSYSTEM)_UNPACK,$1,$2)

BC/unpack/$1/$2: $(call BC_GOAL,unpack,$1,$2)
BC/unpack/$1: BC/unpack/$1/$2
$(if $(findstring $1,$(BC_PACKAGES)),BC/unpack: BC/unpack/$1/$2)
.PHONY: BC/unpack/$1 BC/unpack/$1/$2
# END UNPACK PACKAGE=$1 ARCH=$2

$(if $(filter-out $1,$($1_DEPENDS) $($1_$2_DEPENDS) $(PLATFORM_$2_DEPENDS)),
# DEPENDENCIES $1 $2 $($1_DEPENDS)
$(foreach dep,$(filter-out $1,$($1_DEPENDS) $($1_$2_DEPENDS) $(PLATFORM_$2_DEPENDS)),
$(call BC_GOAL,build,$1,$2): $(call BC_GOAL,install,$(dep),$2)
)
# END DEPENDENCIES
,
# NO DEPENDENCIES FOR $1 $2
)

# BUILD PACKAGE=$1 ARCH=$2
$(call BC_GOAL,build,$1,$2): $(call BC_GOAL,unpack,$1,$2)
$(call BC_GOAL,build,$1,$2): export PATH=$(PATH):$(BC_ROOT)/target/bin
$(call $($1_BUILDSYSTEM)_BUILD,$1,$2)

BC/build/$1/$2: $(call BC_GOAL,build,$1,$2)
BC/build/$1: BC/build/$1/$2
$(if $(findstring $1,$(BC_PACKAGES)),BC/build: BC/build/$1/$2)
.PHONY: BC/build/$1 BC/build/$1/$2
# END BUILD PACKAGE=$1 ARCH=$2

# INSTALL PACKAGE=$1 ARCH=$2
$(call BC_GOAL,install,$1,$2): $(call BC_GOAL,build,$1,$2)
$(call BC_GOAL,install,$1,$2): export PATH=$(PATH):$(BC_ROOT)/target/bin
$(call $($1_BUILDSYSTEM)_INSTALL,$1,$2)

BC/install/$1/$2: $(call BC_GOAL,install,$1,$2)
BC/install/$1: BC/install/$1/$2
$(if $(findstring $1,$(BC_PACKAGES)),BC/install: BC/install/$1/$2)
BC/clear-install/$1/$2:
	rm -f $(call BC_GOAL,install,$1,$2)
BC/clear-install: BC/clear-install/$1/$2
.PHONY: BC/install/$1/$2 BC/clear-install/$1/$2
# END INSTALL PACKAGE=$1 ARCH=$2

# CLEAN PACKAGE=$1 ARCH=$2
BC/clean/$1/$2:
	rm -rf $(call BC_BUILDDIR,$1,$2)/ \
		$(call BC_GOAL,build,$1,$2) \
		$(call BC_GOAL,unpack,$1,$2)

BC/clean/$1: BC/clean/$1/$2
BC/clean: BC/clean/$1/$2
.PHONY: BC/clean/$1/$2
# END CLEAN PACKAGE=$1 ARCH=$2

endef

BC/install:
	for binary in $(BC_ROOT)/target/bin/$(BC_PRIMARY_ARCH)/*; do \
		test -f $$binary && \
		ln -sf $$binary $(BC_ROOT)/target/bin/ || \
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
# generic_UNPACK PACKAGE=$1 ARCH=$2
$(call BC_GOAL,unpack,$1,$2):
	mkdir -p $(call BC_BUILDDIR,$1,$2)
ifeq ($($1_SUFFIX),.tar.gz)
	tar --strip-components=1 --use-compress-program=gzip -xf $($1_TARBALL) -C $(call BC_BUILDDIR,$1,$2)
else ifeq ($($1_SUFFIX),.tar.bz2)
	tar --strip-components=1 --use-compress-program=gzip -xf $($1_TARBALL) -C $(call BC_BUILDDIR,$1,$2)
else ifeq ($($1_SUFFIX),.tar.xz)
	tar --strip-components=1 --use-compress-program=gzip -xf $($1_TARBALL) -C $(call BC_BUILDDIR,$1,$2)
else
	$$(error Could not determine archive format from URL <$($1_URL)>.)
endif
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$1/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$1/$($1_VERSION)/*.patch)),\
		patch -d $(call BC_BUILDDIR,$1,$2) -p1 < $(patch) && ) true
ifneq ($($1_POSTUNPACK),)
	cd $(call BC_BUILDDIR,$1,$2) && $($1_POSTUNPACK)
endif
	mkdir -p $$(@D) && touch $$@
# END generic_UNPACK PACKAGE=$1 ARCH=$2
endef

# Make
make_UNPACK = $(generic_UNPACK)
define make_BUILD
# make_BUILD PACKAGE=$1 ARCH=$2
$(call BC_GOAL,build,$1,$2):
	$(foreach tgt,$(or $(strip $($1_$2_BUILDTARGETS) $($1_BUILDTARGETS)),all),\
	make -C $(call BC_BUILDDIR,$1,$2)/ \
		$($1_BUILDFLAGS) $($1_$2_BUILDFLAGS) \
		CC=$(or $($1_$2_CC),$($1_CC),$$(call BC_CC,$2)) \
		CXX=$(or $($1_$2_CXX),$($1_CXX),$$(call BC_CXX,$2)) \
		$(tgt) && ) true
	mkdir -p $$(@D) && touch $$@
# END autoconf_BUILD PACKAGE=$1 ARCH=$2
endef
define make_INSTALL
# make_INSTALL PACKAGE=$1 ARCH=$2
$(call BC_GOAL,install,$1,$2):
	$(foreach tgt,$(or $(strip $($1_$2_INSTALLTARGETS) $($1_INSTALLTARGETS)),install),\
		$(MAKE) -C $(call BC_BUILDDIR,$1,$2)/ \
			$($1_INSTALLFLAGS) $($1_$2_INSTALLFLAGS) \
			$(tgt))
ifneq ($($1_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$1,$2) && $($1_POSTINSTALL)
endif
ifneq ($($1_$2_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$1,$2) && $($1_$2_POSTINSTALL)
endif
	mkdir -p $$(@D) && touch $$@
# END make_INSTALL PACKAGE=$1 ARCH=$2
endef

# Autoconf
autoconf_UNPACK = $(generic_UNPACK)
define autoconf_BUILD
# autoconf_BUILD PACKAGE=$1 ARCH=$2
$(call BC_GOAL,build,$1,$2):
	cd $(call BC_BUILDDIR,$1,$2) && ./configure \
		--build=$(BC_PRIMARY_ARCH) \
		--host=$2 \
		CC=$(or $($1_$2_CC),$($1_CC),$$(call BC_CC,$2)) \
		CXX=$(or $($1_$2_CXX),$($1_CXX),$$(call BC_CXX,$2)) \
		CPPFLAGS="-I$(BC_ROOT)/target/include/$2" \
		CFLAGS="$(strip $(if $(findstring x86_64,$2),-m64,-m32) $($1_CFLAGS) $($1_$2_CFLAGS))" \
		PKG_CONFIG_PATH=$(BC_ROOT)/target/lib/$2/pkgconfig \
		$($1_CONFIGFLAGS) $($1_$2_CONFIGFLAGS) \
		--prefix=$(BC_ROOT)/target \
		--includedir='$$$$(prefix)/include/$2' \
		--mandir='$$$$(prefix)/share/man' \
		--infodir='$$$$(prefix)/share/info' \
		--sysconfdir='$$$$(prefix)/etc' \
		--libdir='$$$${prefix}/lib/$2' \
		--libexecdir='$$$${prefix}/lib/$2' \
		--bindir='$$$${prefix}/bin/$2' \
		--sbindir='$$$${prefix}/sbin/$2'

	$(MAKE) -C $(call BC_BUILDDIR,$1,$2) $($1_BUILDFLAGS) $($1_$2_BUILDFLAGS)
	mkdir -p $$(@D) && touch $$@
# END autoconf_BUILD PACKAGE=$1 ARCH=$2
endef
define autoconf_INSTALL
# autoconf_INSTALL PACKAGE=$1 ARCH=$2
$(call BC_GOAL,install,$1,$2):
	$(MAKE) -C $(call BC_BUILDDIR,$1,$2)/ install prefix=$(BC_ROOT)/target
ifneq ($($1_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$1,$2) && $($1_POSTINSTALL)
endif
ifneq ($($1_$2_POSTINSTALL),)
	cd $(call BC_BUILDDIR,$1,$2) && $($1_$2_POSTINSTALL)
endif
	mkdir -p $$(@D) && touch $$@
# END autoconf_INSTALL PACKAGE=$1 ARCH=$2
endef

# Golang
BC_GOOS=$(strip \
	$(or $(if $(findstring -linux-,$1),linux),\
		$(if $(filter %-w64-% %-mingw32,$1),windows),\
		$(if $(findstring -darwin,$1),darwin,\
		$(error GOOS: unrecognized architecture $1))))

BC_GOARCH=$(strip \
	$(or $(if $(filter x86_64-%,$1),amd64),\
		$(if $(filter i386-% i686-%,$1),386),\
		$(error GOARCH: unrecognized architecture $1)))

define go_UNPACK
# go_UNPACK PACKAGE=$1 ARCH=$2
$(call BC_GOAL,unpack,$1,$2):
	mkdir -p $(call BC_BUILDDIR,$1,$2)/src/$($1_NAMESPACE)
	tar --strip-components=1 -xzf $($1_TARBALL) -C $(call BC_BUILDDIR,$1,$2)/src/$($1_NAMESPACE)
	$(foreach patch,$(sort $(wildcard $(BC_ROOT)/patches/$1/*.patch)) \
			$(sort $(wildcard $(BC_ROOT)/patches/$1/$($1_VERSION)/*.patch)),\
		patch -d $(call BC_BUILDDIR,$1,$2)/src/$($1_NAMESPACE) -p1 < $(patch))
ifneq ($($1_POSTUNPACK),)
	cd $(call BC_BUILDDIR,$1,$2)/src/$($1_NAMESPACE) && $($1_POSTUNPACK)
endif
	mkdir -p $$(@D) && touch $$@
# END go_UNPACK PACKAGE=$1 ARCH=$2
endef
define go_BUILD
# go_BUILD PACKAGE=$1 ARCH=$2
$(call BC_GOAL,build,$1,$2): export CGO_CFLAGS=-I$(BC_ROOT)/target/include/$2
$(call BC_GOAL,build,$1,$2): export CGO_CFLAGS+=$($1_CGO_CFLAGS)
$(call BC_GOAL,build,$1,$2): export CGO_CFLAGS+=$($1_$2_CGO_CFLAGS)
$(call BC_GOAL,build,$1,$2): export CGO_LDFLAGS=-L$(BC_ROOT)/target/lib/$2
$(call BC_GOAL,build,$1,$2): export CGO_LDFLAGS+=$($1_CGO_LDFLAGS)
$(call BC_GOAL,build,$1,$2): export CGO_LDFLAGS+=$($1_$2_CGO_LDFLAGS)
$(call BC_GOAL,build,$1,$2): export GOPATH=$(call BC_BUILDDIR,$1,$2):$(BC_ROOT)/target/lib/$2/go
$(call BC_GOAL,build,$1,$2): export GOOS=$(call BC_GOOS,$2)
$(call BC_GOAL,build,$1,$2): export GOARCH=$(call BC_GOARCH,$2)
$(call BC_GOAL,build,$1,$2): export CC=$$(call BC_CC,$2)
$(call BC_GOAL,build,$1,$2): export CXX=$$(call BC_CXX,$2)
$(call BC_GOAL,build,$1,$2): export CGO_ENABLED=1
$(call BC_GOAL,build,$1,$2):
	cd $(call BC_BUILDDIR,$1,$2)/ && \
		$(GOROOT)/bin/go install -x --ldflags '-extldflags "-static"' $($1_NAMESPACE)...
	mkdir -p $$(@D) && touch $$@
# END go_BUILD PACKAGE=$1 ARCH=$2
endef
define go_INSTALL
# go_INSTALL PACKAGE=$1 ARCH=$2
$(call BC_GOAL,install,$1,$2):
	mkdir -p $(BC_ROOT)/target/lib/$2/go
	tar -C $(call BC_BUILDDIR,$1,$2) -cf - pkg src | tar -C $(BC_ROOT)/target/lib/$2/go/ -xf -
	mkdir -p $(BC_ROOT)/target/bin/$2
# FIXME: Add a function to filter-out filenames
	$$(foreach binary,\
		$$(wildcard $(call BC_BUILDDIR,$1,$2)/bin/* \
			$(call BC_BUILDDIR,$1,$2)/bin/$(call BC_GOOS,$2)_$(call BC_GOARCH,$2_)/*),\
		if test -f $$(binary); then \
			install -m755 $$(binary) $(BC_ROOT)/target/bin/$2;\
		fi;)
	mkdir -p $$(@D) && touch $$@
# END go_INSTALL PACKAGE=$1 ARCH=$2
endef

# END OF BUILD SYSTEM-SPECIFIC TEMPLATES

# This puts everything together:
$(foreach pkg,$(BC_AVAILABLE_PACKAGES),\
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
	$(foreach pkg,$(BC_AVAILABLE_PACKAGES),\
		$(info $(call GEN_INDEP_TEMPLATE,$(pkg))) \
		$(if $($(pkg)_ARCHS),\
			$(foreach arch,$(sort $($(pkg)_ARCHS)),\
				$(info $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch)))),\
			$(foreach arch,$(sort $(BC_ARCHS)),\
				$(info $(call GEN_ARCH_TEMPLATE,$(pkg),$(arch))))))
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
	$(foreach pkg,$(BC_AVAILABLE_PACKAGES),\
		$(info wget -O- $($(pkg)_URL) > $($(pkg)_TARBALL_LOCAL)))
	@true
