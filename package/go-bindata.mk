go-bindata_VERSION     := 3.0.7
go-bindata_NAMESPACE   := github.com/jteeuwen/go-bindata
go-bindata_URL         := https://$(go-bindata_NAMESPACE)/archive/v$(go-bindata_VERSION).tar.gz
go-bindata_POSTUNPACK  := ./bootstrap.sh
go-bindata_BUILDSYSTEM := go
