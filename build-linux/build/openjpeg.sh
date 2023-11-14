#!/usr/bin/env bash

echo "Install latest compatible openjpeg2"
OPENJPEG2_VERSION=2.5.0
wget -q https://github.com/uclouvain/openjpeg/releases/download/v${OPENJPEG2_VERSION}/openjpeg-v${OPENJPEG2_VERSION}-linux-x86_64.tar.gz -O openjpeg.tar.gz
tar xf openjpeg.tar.gz --strip-components=1 -C /usr/local