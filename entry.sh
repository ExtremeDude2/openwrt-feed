#!/bin/sh

# Can also be set to archive
SERVER="downloads"
BUILD_DIR='build'
VERSION="24.10.4"
ARCH="x86"
PLATFORM="64"
COMPILER="gcc-13.3.0_musl"
mkdir "$BUILD_DIR"

# UPDATE ME! x86_64 release
# Release Page: https://downloads.openwrt.org/releases/
SDK_URL="https://${SERVER}.openwrt.org/releases/${VERSION}/targets/${ARCH}/${PLATFORM}/openwrt-sdk-${VERSION}-${ARCH}-${PLATFORM}_${COMPILER}.Linux-x86_64.tar.zst"
SDK_SUM=229e871f734a2cee5ce3ad6a3e98d3836b0899bfdeaea4d9c2c5cc7b1fce1407
SDK_FILE=$(basename $SDK_URL)

download() {
    echo "Downloading SDK"
    wget $SDK_URL || exit 1
}

setup() {
    # Download file, if it does not exist
    [ -f $SDK_FILE ] || download

    # check that download tar matches expected checksum
    if [ -n "$SDK_SUM" && "$(sha256sum $SDK_FILE | awk '{print $1}')" != "$SDK_SUM" ]; then
       echo "$SDK_FILE does not match sha256 signature"
       exit 1
    fi

    echo "Extracting SDK"
    tar xf $SDK_FILE
    
    echo "Updating and Installing openwrt feeds"
    cd $(basename $SDK_FILE .tar.zst)
    
    cp feeds.conf.default feeds.conf
    echo "src-link pyther /src" >> feeds.conf
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    echo "Generating config and disabling package signing"
    make defconfig
    sed -i 's/CONFIG_SIGNED_PACKAGES=y/CONFIG_SIGNED_PACKAGES=n/' .config
}

if [ ! -d $BUILD_DIR ]; then
   echo "$BUILD_DIR does not exist, did you remember to bind mount it?"
   exit 1
fi

cd $BUILD_DIR

# Check if Directory exists
if [ -d $(basename $SDK_FILE .tar.zst) ]; then
   echo "WARNING: $(basename $SDK_FILE .tar.zst) exists! Skipping setup!"
   cd $(basename $SDK_FILE .tar.zst) || exit 1
else
   setup
fi

PKG=$1
if [ ! -z $PKG ]; then
   echo "$PKG: Download"
   make package/$PKG/download V=s || exit 1
   
   echo "$PKG: Prepare"
   make package/$PKG/prepare V=s || exit 1
   
   echo "$PKG: Compile"
   make package/$PKG/compile V=s || exit 1
fi
