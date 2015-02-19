autoconf_UNPACK = $(generic_UNPACK)

define autoconf_BUILD
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
endef

define autoconf_INSTALL
build/$(1)/$(2)/.install-stamp:
	$(MAKE) -C build/$(1)/$(2)/ install prefix=$(PWD)/target
	touch $$@
endef
