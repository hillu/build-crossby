define generic_UNPACK
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
endef
