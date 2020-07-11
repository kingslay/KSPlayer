#!/bin/bash

# This script downloads and builds the iOS, tvOS and Mac openSSL libraries with Bitcode enabled

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.

OPENSSL_VERSION="openssl-1.0.2t"
LIBRARY_NAME="OpenSSL"
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
	TARGET="darwin64-x86_64-cc"
	export CROSS_TOP="${XCODE_PATH}/Platforms/MacOSX.platform/Developer"
	export CROSS_SDK="MacOSX.sdk"
	export CC="/usr/bin/clang -arch ${ARCH} -fembed-bitcode -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET} -fno-common"
	pushd . >/dev/null
	cd "${OPENSSL_VERSION}"
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &>"${TARGETDIR}.log"
	make >>"${TARGETDIR}.log" 2>&1
	make install_sw >>"${TARGETDIR}.log" 2>&1
	make clean >>"${TARGETDIR}.log" 2>&1
	popd >/dev/null
}

buildMacCatalyst() {
	ARCH=$2
	TARGETDIR=$3
	echo "Building ${OPENSSL_VERSION} for ${ARCH}"
	TARGET="darwin64-x86_64-cc"
	export CROSS_TOP="${XCODE_PATH}/Platforms/MacOSX.platform/Developer"
	export CROSS_SDK="MacOSX.sdk"
	export CC="/usr/bin/clang -arch ${ARCH} -fembed-bitcode -fno-common"
	pushd . >/dev/null
	cd "${OPENSSL_VERSION}"
	./Configure ${TARGET} --target=x86_64-apple-ios13.0-macabi -mmacosx-version-min=10.15 --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &>"${TARGETDIR}.log"
	make >>"${TARGETDIR}.log" 2>&1
	make install_sw >>"${TARGETDIR}.log" 2>&1
	make clean >>"${TARGETDIR}.log" 2>&1
	popd >/dev/null
}

buildIOS() {
	ARCH=$2
	TARGETDIR=$3
	pushd . >/dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${XCODE_PATH}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}.sdk"
	export CC="${XCODE_PATH}/usr/bin/gcc -fembed-bitcode -arch ${ARCH} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} -isysroot $CROSS_TOP/SDKs/$CROSS_SDK"
	
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	TARGET="iphoneos-cross"
	if [[ "${ARCH}" == "x86_64" ]]; then
		TARGET="no-asm darwin64-x86_64-cc"
	elif [[ "${ARCH}" == "i386" ]]; then
		TARGET="no-asm darwin-i386-cc"
	fi
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &>"${TARGETDIR}.log"
	make >>"${TARGETDIR}.log" 2>&1
	make install_sw >>"${TARGETDIR}.log" 2>&1
	make clean >>"${TARGETDIR}.log" 2>&1
	popd >/dev/null
}

buildTVOS() {
	ARCH=$2
	TARGETDIR=$3
	pushd . >/dev/null
	cd "${OPENSSL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="AppleTVSimulator"
	else
		PLATFORM="AppleTVOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi

	export $PLATFORM
	export CROSS_TOP="${XCODE_PATH}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="$PLATFORM.sdk"
	export CC="${XCODE_PATH}/usr/bin/gcc -fembed-bitcode -arch ${ARCH} -mtvos-version-min=${TVOS_MIN_SDK_VERSION} -isysroot $CROSS_TOP/SDKs/$CROSS_SDK"

	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${TVOS_SDK_VERSION} ${ARCH}"

	# Patch apps/speed.c to not use fork() since it's not available on tvOS
	LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "./apps/speed.c"
	LANG=C sed -i -- 's/define OCSP_DAEMON//' "./apps/ocsp.c"

	# Patch Configure to build for tvOS, not iOS
	LANG=C sed -i -- 's/D\_REENTRANT\:iOS/D\_REENTRANT\:tvOS/' "./Configure"
	chmod u+x ./Configure
	TARGET="iphoneos-cross"
	if [[ "${ARCH}" == "x86_64" ]]; then
		TARGET="no-asm  darwin64-x86_64-cc"
	fi
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &>"${TARGETDIR}.log"
	make >>"${TARGETDIR}.log" 2>&1
	make install_sw >>"${TARGETDIR}.log" 2>&1
	make clean >>"${TARGETDIR}.log" 2>&1
	popd >/dev/null
}
function PackageToLibrary() {
	local platform=$1
	local arch=$2

	echo "${ORANGE}Packaging library for platform: $platform, arch: $arch ${NOCOLOR}"
	local build_dir="./$LIBRARY_NAME/$platform/scratch/$arch"
	local thin_dir="./$LIBRARY_NAME/$platform/thin/$arch"
	mkdir -p $thin_dir/include/
	mkdir -p $thin_dir/lib/
	cp -R $build_dir/include/ $thin_dir/include/
	cp $build_dir/lib/*.a $thin_dir/lib
}
function CreateModulemap() {
	local framework=$1
}
if [ ! -e ${OPENSSL_VERSION} ]; then
	if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
		echo "Downloading ${OPENSSL_VERSION}.tar.gz"
		curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
	else
		echo "Using ${OPENSSL_VERSION}.tar.gz"
	fi

	echo "Unpacking openssl"
	tar xfz "${OPENSSL_VERSION}.tar.gz"
fi

BuildAll
CreateXCFramework

echo "Done"
