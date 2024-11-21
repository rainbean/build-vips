PKG             := openslide
$(PKG)_WEBSITE  := https://openslide.org/
$(PKG)_DESCR    := C library for reading virtual slide images.
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2024-11-21
$(PKG)_CHECKSUM := 8058299476d3fee3c56db489c52ffed78c4c86917520b1d2fb7f4090bfff0d9c
$(PKG)_PATCHES  := $(realpath $(sort $(wildcard $(dir $(lastword $(MAKEFILE_LIST)))/patches/$(PKG)-[0-9]*.patch)))
$(PKG)_GH_CONF  := rainbean/openslide/tags
$(PKG)_DEPS     := cc zlib glib libxml2 cairo gdk-pixbuf libjpeg-turbo tiff openjpeg sqlite libdicom zstd

define $(PKG)_BUILD
    $(MXE_MESON_WRAPPER) \
        -Dtest=disabled \
        -Ddoc=disabled \
        '$(SOURCE_DIR)' \
        '$(BUILD_DIR)'

    $(MXE_NINJA) -C '$(BUILD_DIR)' -j '$(JOBS)' install
endef
