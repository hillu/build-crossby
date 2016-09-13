yara_VERSION     := 3.5.0
yara_URL         := https://github.com/VirusTotal/yara/archive/v$(yara_VERSION).tar.gz
yara_POSTUNPACK  := ./bootstrap.sh
yara_BUILDSYSTEM := autoconf

yara_CONFIGFLAGS  := --disable-magic --disable-cuckoo --without-crypto
