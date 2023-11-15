FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
	apt-get install -y \
		build-essential \
		ninja-build \
		unzip \
		wget \
		libglib2.0-dev \
		libexpat1-dev \
		python-is-python3 \
		python3-pip \
		autoconf \
		libtool \
		nasm \
		clang \
		libcairo2-dev \
		libgdk-pixbuf2.0-dev \
		libpng-dev \
		libjpeg-turbo8-dev \
		libgif-dev \
		libtiff-dev \
		libexif-dev \
		libgsf-1-dev \
		libarchive-dev \
		libwebp-dev \
		libbrotli-dev \
		liborc-dev \
		libsqlite3-dev

# Install meson
RUN pip3 install meson

# The build dir is mounted at /data, so this runs the build script in that
ENTRYPOINT ["/bin/bash", "/data/build.sh"]

# The build dir is mounted here
WORKDIR /data
