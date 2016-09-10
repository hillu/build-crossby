musl_VERSION     := 1.1.15
musl_URL         := http://www.musl-libc.org/releases/musl-$(musl_VERSION).tar.gz

musl_BUILDSYSTEM := autoconf

# There is no compiler toolchain with (i386|x86_64)-linux-gnu prefix.
musl_BUILDFLAGS := CROSS_COMPILE=

musl_ARCHS  := i386-linux-musl x86_64-linux-musl

# Patch the .specs file so we can can build both i386 and x86_64
# binaries, provided we have a multilib-enabled GCC.
musl_x86_64-linux-musl_POSTINSTALL := \
	ln -s $(BC_ROOT)/target/bin/x86_64-linux-musl/musl-gcc \
		$(BC_ROOT)/target/bin/x86_64-linux-musl-gcc && \
	sed -i -e 's/^-dynamic-linker/-m elf_x86_64 &/' \
		-e '$$$$a *multilib:\n64:../lib64:x86_64-linux-gnu m64;\n\n*multilib_defaults:\nm64\n\n*asm:\n--64\n\n*cc1_cpu:\n-m64' \
		$(BC_ROOT)/target/lib/x86_64-linux-musl/musl-gcc.specs
musl_i386-linux-musl_POSTINSTALL := \
	ln -s $(BC_ROOT)/target/bin/i386-linux-musl/musl-gcc \
		$(BC_ROOT)/target/bin/i386-linux-musl-gcc && \
	sed -i -e 's/^-dynamic-linker/-m elf_i386 &/' \
		-e '$$$$a *multilib:\n32:../lib32:i386-linux-gnu m32;\n\n*multilib_defaults:\nm32\n\n*asm:\n--32\n\n*cc1_cpu:\n-m32' \
		$(BC_ROOT)/target/lib/i386-linux-musl/musl-gcc.specs
