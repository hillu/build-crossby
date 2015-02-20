define go_UNPACK
build/$(1)/$(2)/.unpack-stamp:
	mkdir -p build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	tar --strip=1 -xzf $($(1)_TARBALL) -C build/$(1)/$(2)/src/$($(1)_NAMESPACE)
	for patch in $(wildcard patches/$(1)/$($(1)_VERSION)/*.patch); do \
		patch -d build/$(1)/$(2)/src/$($(1)_NAMESPACE) -p1 < $$$$patch ; \
	done
	touch $$@
endef

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


define go_BUILD
build/$(1)/$(2)/.build-stamp:
	@echo ARCH=$(2)
	echo GOOS=$(call GOOS,$(2))
	echo GOARCH=$(call GOARCH,$(2))
	cd build/$(1)/$(2)/ && \
		CGO_CFLAGS=-I$(PWD)/target/include \
		CGO_LDFLAGS=-L$(PWD)/target/lib/$(2) \
		GOPATH=$(PWD)/build/$(1)/$(2) \
		GOOS=$(call GOOS,$(2)) GOARCH=$(call GOARCH,$(2)) \
		CC=$(call CGO_CC,$(2)) \
		CGO_ENABLED=1 \
		go install -x --ldflags '-extldflags "-static"' $($(1)_NAMESPACE)
	touch $$@
endef

define go_INSTALL
build/$(1)/$(2)/.install-stamp:
	mkdir -p $(PWD)/target/lib/go
	cp -rt $(PWD)/target/lib/go/ build/$(1)/$(2)/pkg build/$(1)/$(2)/src
	touch $$@
endef
