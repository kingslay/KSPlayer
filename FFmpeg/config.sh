#!/bin/sh
ORANGE="\033[1;93m"
RED="\033[1;91m"
MAGENTA="\033[1;35m"
NOCOLOR="\033[0m"

FF_VERSION="4.2.2"
if [[ $FFMPEG_VERSION != "" ]]; then
    FF_VERSION=$FFMPEG_VERSION
fi
##### Add Begin #####
# OpenSSL
OPENSSL=$(pwd)/OpenSSL

#####  Add End  #####
SOURCE="ffmpeg-$FF_VERSION"
XCODE_PATH=$(xcode-select -p)

CONFIGURE_FLAGS="--enable-optimizations"
# Licensing options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-gpl"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-version3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-nonfree"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-debug"

# Configuration options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-cross-compile"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-stripping"

CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-thumb"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-static"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-shared"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-runtime-cpudetect"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-gray"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-swscale-alpha"

# Program options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-programs"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-ffmpeg"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-ffplay"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-ffprobe"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-ffserver"

# Documentation options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-doc"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-htmlpages"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-manpages"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-podpages"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-txtpages"

# Component options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-avdevice"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avcodec"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avformat"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avutil"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-swresample"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-swscale"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-postproc"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-avfilter"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-avresample"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-pthreads"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-w32threads"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-os2threads"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-network"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-dct"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-dwt"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-lsp"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-lzo"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-mdct"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-rdft"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-fft"

# Hardware accelerators:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-dxva2"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-vaapi"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-vda"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-vdpau"

# Individual component options:
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-everything"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-encoders"

# ./configure --list-decoders
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-decoders"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=dca"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=flv"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=h263"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=h263i"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=h263p"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=h264"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=hevc"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mjpeg"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mjpegb"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mpeg1video"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mpeg2video"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mpeg4"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mpegvideo"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=rv30"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=rv40"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=tscc"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=wmv1"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=wmv2"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=wmv3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vc1"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp6"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp6a"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp6f"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp7"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp8"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vp9"
#音频
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=aac"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=aac_latm"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=ac3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=alac"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=amrnb"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=amrwb"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=ape"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=cook"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=dca"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=eac3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=flac"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mp1"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mp2"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=mp3*"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=opus"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=pcm*"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=wma*"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=vorbis"
#字幕
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=ass"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=srt"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=ssa"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=movtext"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=subrip"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-decoder=dvdsub"

CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-hwaccels"
# ./configure --list-muxers
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-muxers"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-muxer=mpegts"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-muxer=mp4"

# ./configure --list-demuxers
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-demuxers"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=aac"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=concat"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=data"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=flv"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=hls"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=latm"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=live_flv"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=loas"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=m4v"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=mov"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=mp3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=mpegps"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=mpegts"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=mpegvideo"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=hevc"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=dash"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=wav"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=ogg"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=ape"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=aiff"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=flac"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=amr"

CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=asf"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=avi"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=matroska"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=rm"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=webm_dash_manifest"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-demuxer=vc1"

# ./configure --list-bsf
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsfs"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsf=mjpeg2jpeg"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsf=mjpeg2jpeg"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsf=mjpega_dump_header"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsf=mov2textsub"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bsf=text2movsub"

#
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-devices"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-indevs"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-outdevs"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-filters"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-iconv"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-audiotoolbox"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-videotoolbox"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-linux-perf"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-bzlib"


if [ "$X264" ]; then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264"
fi

if [ "$FDK_AAC" ]; then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac --enable-nonfree"
fi

if [ "$OPENSSL" ]; then
    CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-openssl"
fi
function ConfigureForIOS() {
    local arch=$1
    DEPLOYMENT_TARGET="9.0"
    PLATFORM="iPhoneOS"

    LIBTOOL_FLAGS="\
		 -syslibroot $XCODE_PATH/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk \
		 -L$XCODE_PATH/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/iOSSupport/usr/lib"

    CFLAGS="-arch $arch"

    if [ "$arch" = "i386" -o "$arch" = "x86_64" ]; then
        PLATFORM="iPhoneSimulator"
        CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
        FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --disable-asm --disable-mmx --assert-level=2"
    else
        CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --enable-pic --enable-neon --enable-small"
        if [ "$ARCH" = "arm64" ]; then
            EXPORT="GASPP_FIX_XCODE5=1"
        fi
    fi
}

function ConfigureForTVOS() {
    local arch=$1
    DEPLOYMENT_TARGET="12.0"
    PLATFORM="AppleTVOS"

    LIBTOOL_FLAGS="\
		 -syslibroot $XCODE_PATH/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk \
		 -L$XCODE_PATH/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk/System/usr/lib"

    CFLAGS="-arch $arch"

    if [ "$arch" = "i386" -o "$arch" = "x86_64" ]; then
        PLATFORM="AppleTVSimulator"
        CFLAGS="$CFLAGS -mtvos-simulator-version-min=$DEPLOYMENT_TARGET"
        FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --disable-asm --disable-mmx --assert-level=2"
    else
        CFLAGS="$CFLAGS -mtvos-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
        FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --enable-pic --enable-neon"
        if [ "$ARCH" = "arm64" ]; then
            EXPORT="GASPP_FIX_XCODE5=1"
        fi
    fi
}

function ConfigureForMacOS() {
    local arch=$1
    DEPLOYMENT_TARGET="10.14"
    PLATFORM="MacOSX"

    LIBTOOL_FLAGS="\
		 -syslibroot $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
		 -L$XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/usr/lib"

    CFLAGS="-arch $arch"
    FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --disable-asm"
    CFLAGS="$CFLAGS -mmacosx-version-min=$DEPLOYMENT_TARGET"
}

function ConfigureForMacCatalyst() {
    local arch=$1
    DEPLOYMENT_TARGET="10.15"
    PLATFORM="iPhoneOS"

    LIBTOOL_FLAGS="\
		-syslibroot $XCODE_PATH/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk \
		-L$XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk/System/iOSSupport/usr/lib \
		-L$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/maccatalyst"

    CFLAGS="-arch $arch"
    FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --disable-asm"
    CFLAGS="$CFLAGS -target x86_64-apple-ios13.0-macabi \
						-isysroot $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
						-isystem $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/usr/include \
						-iframework $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOS.sdk/System/iOSSupport/System/Library/Frameworks"

    LDFLAGS="$LDFLAGS -target x86_64-apple-ios13.0-macabi \
				-isysroot $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
				-L$XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/usr/lib \
				-L$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/maccatalyst \
				-iframework $XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/iOSSupport/System/Library/Frameworks"
}
