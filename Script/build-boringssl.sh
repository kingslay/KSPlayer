#!/bin/bash

# This script downloads and builds the iOS, tvOS and Mac openSSL libraries with Bitcode enabled

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.

OPENSSL_VERSION="boringssl"
LIBRARY_NAME="boringssl"
source common.sh
export LC_CTYPE=C
set -e
usage() {
	echo "usage: $0 [iOS SDK version (defaults to latest)] [tvOS SDK version (defaults to latest)] [OS X minimum deployment target (defaults to 10.7)]"
	exit 127
}

if [ $1 -e "-h" ]; then
	usage
fi

if [ -z $1 ]; then
	IOS_SDK_VERSION="" #"9.1"
	IOS_MIN_SDK_VERSION="8.0"

	TVOS_SDK_VERSION="" #"9.0"
	TVOS_MIN_SDK_VERSION="9.0"

	OSX_DEPLOYMENT_TARGET="10.7"
else
	IOS_SDK_VERSION=$1
	TVOS_SDK_VERSION=$2
	OSX_DEPLOYMENT_TARGET=$3
fi

DEVELOPER=$(xcode-select -print-path)
buildMac() {
	ARCH=$2
	TARGETDIR=$3
	echo "Building ${OPENSSL_VERSION} for ${ARCH}"
	mkdir -p $TARGETDIR
	cd $TARGETDIR
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	cmake -GNinja ../../..
	ninja
	cd ../../../..
}

buildMacCatalyst() {
	ARCH=$2
	TARGETDIR=$3
	echo "Building ${OPENSSL_VERSION} for ${ARCH}"
	mkdir -p $TARGETDIR
	cd $TARGETDIR
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	CFLAGS="-target x86_64-apple-ios13.1-macabi"
	cmake --target=x86_64-apple-ios13.0-macabi -DCMAKE_C_FLAGS="-target x86_64-apple-ios13.1-macabi" ../../..
	make
	cd ../../../..
}

buildIOS() {
	ARCH=$2
	TARGETDIR=$3
	cd "${OPENSSL_VERSION}"
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iphonesimulator"
	else
		PLATFORM="iphoneos"
		# sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
	mkdir -p $TARGETDIR
	cd $TARGETDIR
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	cmake -DCMAKE_OSX_SYSROOT=${PLATFORM} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -GNinja ../../..
	ninja
	cd ../../../..
}

buildTVOS() {
	ARCH=$2
	TARGETDIR=$3
	pushd . >/dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="appletvsimulator"
	else
		PLATFORM="appletvos"
		# sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
	mkdir -p $TARGETDIR
	cd $TARGETDIR
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	cmake -DCMAKE_OSX_SYSROOT=${PLATFORM} -DCMAKE_OSX_ARCHITECTURES=${ARCH} -GNinja ../../..
	ninja
	cd ../../../..
}
function PackageToLibrary() {
	local platform=$1
	local arch=$2

	echo "${ORANGE}Packaging library for platform: $platform, arch: $arch ${NOCOLOR}"
	local build_dir="./$LIBRARY_NAME/$platform/scratch/$arch"
	local thin_dir="./$LIBRARY_NAME/$platform/thin/$arch"
	mkdir -p $thin_dir/include/
	mkdir -p $thin_dir/lib/
	cp -R ./$LIBRARY_NAME/include/ $thin_dir/include/
	cp $build_dir/crypto/*.a $thin_dir/lib
	cp $build_dir/ssl/*.a $thin_dir/lib
}
function CreateModulemap() {
	local framework=$1
}
if [ ! -e ${OPENSSL_VERSION} ]; then
	git clone https://github.com/google/boringssl.git
fi
if [ ! $(which brew) ]; then
	echo "${RED}Homebrew not found. Trying to install... ${NOCOLOR}"
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
fi
if [ ! $(which cmake) ]; then
	echo 'cmake not found'
	echo 'Trying to install cmake...'
	brew install cmake || exit 1
fi
if [ ! $(which ninja) ]; then
	echo 'ninja not found'
	echo 'Trying to install ninja...'
	brew install ninja || exit 1
fi
if [ ! $(which go) ]; then
	echo 'go not found'
	echo 'Trying to install go...'
	brew install go || exit 1
fi
set -e

BuildAll
CreateXCFramework

echo "Done"
