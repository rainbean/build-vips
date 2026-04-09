#!/usr/bin/env bash

# Derive architecture label and library triplet from the running kernel
case $(uname -m) in
    x86_64)  arch_label="x64";  arch_triplet="x86_64-linux-gnu" ;;
    aarch64) arch_label="arm64"; arch_triplet="aarch64-linux-gnu" ;;
    *)       arch_label=$(uname -m); arch_triplet="$(uname -m)-linux-gnu" ;;
esac

target="$work_dir/vips-linux-${arch_label}-$(date +%F).tar"

cd /usr/local/bin
tar cf $target vips vipsheader

cd /usr/local/lib
tar rf $target libopenjp2* libjpeg.so* libtiff.so*

cd /usr/local/lib/${arch_triplet}
tar rf $target liblcms2.so* libspng.so* libvips-cpp.so* libvips.so* libdicom.so* libopenslide.so*

# fix wrong symbolic link path
cd /usr/lib/${arch_triplet}/
rm -f libexpat.so
ln -s libexpat.so.1 libexpat.so
rm -f liblzma.so
ln -s liblzma.so.5 liblzma.so

cd /usr/lib/${arch_triplet}/
tar rf $target \
    libglib-2.0.so* libgobject-2.0.so* libgmodule-2.0.so* libgio-2.0.so* libexpat.so* libzstd.so* \
    libexif.so* libwebpmux.so* libwebpdemux.so* libwebp.so* libffi.so* \
    libxml2.so* libpng16* liblzma.so* \
    libpcre.so* libsqlite3.so* libbrotlidec.so* \
    libbrotlicommon.so* libbrotlienc.so* libicuuc.so* libicudata.so* \
    libarchive.so* libdeflate.so*

tar rf $target -C /repo LICENSE THIRD-PARTY-NOTICES

gzip $target
