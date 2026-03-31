FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
	apt-get install -y \
		build-essential \
		ninja-build \
		unzip \
		wget \
		libglib2.0-dev \
		libexpat1-dev \
		autoconf \
		libtool \
		clang \
		meson \
		libcairo2-dev \
		zlib1g-dev \
		libzstd-dev \
		libjpeg-dev \
		libpng-dev \
		libtiff-dev \
		libexif-dev \
		libwebp-dev \
		libbrotli-dev \
		libxml2-dev \
		libsqlite3-dev \
		libgdk-pixbuf2.0-dev

# The build dir is mounted at /data, so this runs the build script in that
ENTRYPOINT ["/bin/bash", "/data/build.sh"]

# The build dir is mounted here
WORKDIR /data
