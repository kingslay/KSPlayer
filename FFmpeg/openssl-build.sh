#!/bin/bash

# This script downloads and builds the iOS, tvOS and Mac openSSL libraries with Bitcode enabled

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# https://gist.github.com/foozmeat/5154962
# https://gist.github.com/felix-schwarz/c61c0f7d9ab60f53ebb0
# Peter Steinberger, PSPDFKit GmbH, @steipete.
# Felix Schwarz, IOSPIRIT GmbH, @felix_schwarz.
export LC_CTYPE=C
set -e

usage ()
{
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

OPENSSL_VERSION="openssl-1.1.1"
DEVELOPER=`xcode-select -print-path`

buildMac()
{
	ARCH=$1

	echo "Building ${OPENSSL_VERSION} for ${ARCH}"
  	SDKVERSION=$(xcrun -sdk macosx --show-sdk-version)
	TARGET="darwin64-x86_64-cc"
 	export CROSS_TOP="${DEVELOPER}/Platforms/MacOSX.platform/Developer"
  	export CROSS_SDK="MacOSX${SDKVERSION}.sdk"
	export CC="${BUILD_TOOLS}/usr/bin/clang -arch ${ARCH} -fembed-bitcode -mmacosx-version-min=${OSX_DEPLOYMENT_TARGET} -isysroot \$(CROSS_TOP)/SDKs/\$(CROSS_SDK) -fno-common"

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
	TARGETDIR="/tmp/${OPENSSL_VERSION}-${ARCH}"
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &> "${TARGETDIR}.log"
	make >> "${TARGETDIR}.log" 2>&1
	make install_sw >> "${TARGETDIR}.log" 2>&1
	make clean >> "${TARGETDIR}.log" 2>&1
	popd > /dev/null
}

buildIOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} -isysroot \$(CROSS_TOP)/SDKs/\$(CROSS_SDK)"
   
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
	TARGETDIR="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}"
	TARGET="iphoneos-cross"
	if [[ "${ARCH}" == "x86_64" ]]; then
		TARGET="no-asm darwin64-x86_64-cc"
	elif [[ "${ARCH}" == "i386" ]]; then
		TARGET="no-asm darwin-i386-cc"
	fi
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &> "${TARGETDIR}.log"
	make >> "${TARGETDIR}.log" 2>&1
	make install_sw >> "${TARGETDIR}.log" 2>&1
	make clean >> "${TARGETDIR}.log" 2>&1
	popd > /dev/null
}

buildTVOS()
{
	ARCH=$1

	pushd . > /dev/null
	cd "${OPENSSL_VERSION}"
  
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="AppleTVSimulator"
	else
		PLATFORM="AppleTVOS"
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
	fi
  
	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${TVOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH} -mtvos-version-min=${TVOS_MIN_SDK_VERSION} -isysroot \$(CROSS_TOP)/SDKs/\$(CROSS_SDK)"
   
	echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${TVOS_SDK_VERSION} ${ARCH}"

	# Patch apps/speed.c to not use fork() since it's not available on tvOS
	LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "./apps/speed.c"
	LANG=C sed -i -- 's/define OCSP_DAEMON//' "./apps/ocsp.c"


	# Patch Configure to build for tvOS, not iOS
	LANG=C sed -i -- 's/D\_REENTRANT\:iOS/D\_REENTRANT\:tvOS/' "./Configure"
	chmod u+x ./Configure
	TARGETDIR=/tmp/${OPENSSL_VERSION}-tvOS-${ARCH}
	TARGET="iphoneos-cross"
	if [[ "${ARCH}" == "x86_64" ]]; then
		TARGET="no-asm  darwin64-x86_64-cc"
	fi
	./Configure ${TARGET} --prefix=${TARGETDIR} no-async no-shared --openssldir=${TARGETDIR} &> "${TARGETDIR}.log"
	make >> "${TARGETDIR}.log" 2>&1
	make install_sw >> "${TARGETDIR}.log" 2>&1
	make clean >> "${TARGETDIR}.log" 2>&1
	popd > /dev/null
}


echo "Cleaning up"
rm -rf openssl-macOS/* openssl-iOS/* openssl-tvOS/*

mkdir -p openssl-macOS/lib
mkdir -p openssl-macOS/include/openssl/
mkdir -p openssl-iOS/lib
mkdir -p openssl-iOS/include/openssl/
mkdir -p openssl-tvOS/lib
mkdir -p openssl-tvOS/include/openssl/
rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"

rm -rf "${OPENSSL_VERSION}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
	echo "Downloading ${OPENSSL_VERSION}.tar.gz"
	curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
	echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

buildMac "x86_64"

echo "Building Mac libraries"
lipo \
   "/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
   -create -output openssl-macOS/lib/libcrypto.a

lipo \
   "/tmp/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
   -create -output openssl-macOS/lib/libssl.a

buildIOS "armv7"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

echo "Building iOS libraries"
lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
   -create -output openssl-iOS/lib/libcrypto.a

lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
   -create -output openssl-iOS/lib/libssl.a
buildTVOS "arm64"
buildTVOS "x86_64"

echo "Building tvOS libraries"
lipo \
	"/tmp/${OPENSSL_VERSION}-tvOS-arm64/lib/libcrypto.a" \
	"/tmp/${OPENSSL_VERSION}-tvOS-x86_64/lib/libcrypto.a" \
	-create -output openssl-tvOS/lib/libcrypto.a

lipo \
	"/tmp/${OPENSSL_VERSION}-tvOS-arm64/lib/libssl.a" \
	"/tmp/${OPENSSL_VERSION}-tvOS-x86_64/lib/libssl.a" \
	-create -output openssl-tvOS/lib/libssl.a

echo "Copying headers"
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* openssl-macOS/include/openssl/
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* openssl-iOS/include/openssl/
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* openssl-tvOS/include/openssl/

echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

echo "Done"
