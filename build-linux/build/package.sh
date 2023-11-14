#!/usr/bin/env bash

target="$work_dir/vips-linux-$(date +%F).tar"

cd /usr/local/bin
tar cf $target vips vipsheader

cd /usr/local/lib
tar rf $target libjpeg.so* libjxl.so* libjxl_threads.so* libopenjp2*

cd /usr/local/lib/x86_64-linux-gnu
tar rf $target liblcms2.so* libspng.so* libvips-cpp.so* libvips.so* libdicom.so* libopenslide.so*

# fix wrong symbolic link path
cd /usr/lib/x86_64-linux-gnu/
rm libexpat.so
ln -s libexpat.so.1.6.11 libexpat.so
rm liblzma.so
ln -s liblzma.so.5.2.4 liblzma.so

cd /usr/lib/x86_64-linux-gnu/
tar rf $target \
    libglib-2.0.so* libgobject-2.0.so* libgmodule-2.0.so* libgio-2.0.so* libexpat.so* libzstd.so* libjpeg.so* \
    libexif.so* libwebpmux.so* libwebpdemux.so* libwebp.so* libtiff.so* libcairo.so* libffi.so* \
    liborc-0.4.so* libxml2.so* libjbig.so* libcairo-gobject.so* libpixman-1.so* libpng16* liblzma.so* \
    libsqlite3.so* libbrotlidec.so* libbrotlicommon.so* libbrotlienc.so* libicuuc.so* libicudata.so*

gzip $target
