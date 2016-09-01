yara_VERSION     := 3.5.0
yara_URL         := https://github.com/VirusTotal/yara/archive/v$(yara_VERSION).tar.gz
yara_POSTUNPACK  := ./bootstrap.sh
yara_BUILDSYSTEM := autoconf

yara_CONFIGFLAGS  := --disable-magic --disable-cuckoo --without-crypto

# yara_i686-w64-mingw32_CFLAGS := -D__MINGW_USE_VC2005_COMPAT

yara_SUFFIX      := .tar.gz

yara_ARCHS       := $(BC_ARCHS) x86_64-linux-musl i386-linux-musl

yara_x86_64-linux-musl_DEPENDS := musl
yara_i386-linux-musl_DEPENDS   := musl
