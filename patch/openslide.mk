PKG             := openslide
$(PKG)_WEBSITE  := https://openslide.org/
$(PKG)_DESCR    := C library for reading virtual slide images.
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2025-08-22
$(PKG)_CHECKSUM := 424e52a423ac3124f97a4fd578924c0ec5d2d109bf929f8043940780bae9b7c8
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
