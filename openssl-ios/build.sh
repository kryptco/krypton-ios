#!/bin/sh
#
# Build libssl for iOS
# Check if artificats exist so not to rebuild each time

CURRENTPATH=$(pwd)

if [ -f "${CURRENTPATH}/lib/libssl.a" ]; then
    echo "libssl has already been built, skipping."
    exit 0
fi

./build-libssl.sh
./create-frameworks.sh