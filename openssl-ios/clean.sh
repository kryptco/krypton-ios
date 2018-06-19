#!/bin/sh
#
# Clean artificats for libssl

CURRENTPATH=$(pwd)

if [ -d "${CURRENTPATH}/bin" ]; then
    rm -r "${CURRENTPATH}/bin"
fi
if [ -d "${CURRENTPATH}/include/openssl" ]; then
    rm -r "${CURRENTPATH}/include/openssl"
fi
if [ -d "${CURRENTPATH}/lib" ]; then
    rm -r "${CURRENTPATH}/lib"
fi
if [ -d "${CURRENTPATH}/src" ]; then
    rm -r "${CURRENTPATH}/src"
fi