PKG             := openslide
$(PKG)_WEBSITE  := https://openslide.org/
$(PKG)_DESCR    := C library for reading virtual slide images.
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 2024-06-12
$(PKG)_CHECKSUM := a02c6c94807a79db0865e5a327aff531aacfe2b9b6bb22a6324af1f4fec870f7
$(PKG)_PATCHES  := $(realpath $(sort $(wildcard $(dir $(lastword $(MAKEFILE_LIST)))/patches/$(PKG)-[0-9]*.patch)))
$(PKG)_GH_CONF  := rainbean/openslide/tags
$(PKG)_DEPS     := cc zlib glib libxml2 cairo gdk-pixbuf libjpeg-turbo tiff openjpeg sqlite libdicom

define $(PKG)_BUILD
    $(MXE_MESON_WRAPPER) \
        -Dtest=disabled \
        -Ddoc=disabled \
        '$(SOURCE_DIR)' \
        '$(BUILD_DIR)'

    $(MXE_NINJA) -C '$(BUILD_DIR)' -j '$(JOBS)' install
endef
