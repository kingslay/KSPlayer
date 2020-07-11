#!/bin/sh

source ffmpegConfig.sh

LIBRARY_NAME="FFmpeg"
source common.sh
parameter=$1
function InnerBuild() {
    local platform=$1
    local arch=$2
    if [[ $parameter = "debug" && $platform = "macos" ]]; then
        FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --enable-ffmpeg --enable-ffplay --enable-sdl2 --enable-encoder=mpeg4 --enable-encoder=aac --enable-muxer=m4v --enable-muxer=dash"
    else
        FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-programs --disable-ffmpeg --disable-ffplay --disable-ffprobe --disable-avfilter --disable-filters"
    fi
    if ! [[ $parameter = "debug" && $platform = "maccatalyst" ]]; then
        FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-debug"
    fi
    echo "${ORANGE}Building for platform: $platform, arch: $arch ${NOCOLOR}"

    local current_dir=$(pwd)
    local build_dir="$LIBRARY_NAME/$platform/scratch/$arch"
    local thin="$current_dir/$LIBRARY_NAME/$platform/thin"
    local prefix="$thin/$arch"

    mkdir -p "$build_dir"
    cd "$build_dir"

    local xcrun_sdk=$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')
    CC="xcrun -sdk $xcrun_sdk clang"

    if [ "$X264" ]; then
        CFLAGS="$CFLAGS -I$X264/include"
        LDFLAGS="$LDFLAGS -L$X264/lib"
    fi

    if [ "$FDK_AAC" ]; then
        CFLAGS="$CFLAGS -I$FDK_AAC/include"
        LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
    fi

    if [ "$OPENSSL" ]; then
        OPENSSLPath=$OPENSSL/$platform/thin/${arch}
        CFLAGS="$CFLAGS -I$OPENSSLPath/include"
        LDFLAGS="$LDFLAGS -L$OPENSSLPath/lib"
    fi
    
    $current_dir/$SOURCE/configure  --target-os=darwin --arch=$arch --cc="$CC" $FFMPEG_CFG_FLAGS --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" --prefix="$prefix" || exit 1
    make -j8 install $EXPORT || exit 1
    if [[ $parameter = "debug" && $platform = "macos" ]]; then
        cp $prefix/bin/ffmpeg /usr/local/bin
        cp $prefix/bin/ffplay /usr/local/bin
        cp $prefix/bin/ffprobe /usr/local/bin
    fi
    cd $current_dir
}

function PrepareYasm() {
    if [ ! $(which brew) ]; then
        echo "${RED}Homebrew not found. Trying to install... ${NOCOLOR}"
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    fi
    if [ ! $(which yasm) ]; then
        echo 'Yasm not found'
        echo 'Trying to install Yasm...'
        brew install yasm || exit 1
    fi
    if [ ! $(which pkg-config) ]; then
        brew install pkg-config || exit 1
    fi

    if [ ! -r $SOURCE ]; then
        echo 'FFmpeg source not found. Trying to download...'
        curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj ||
            exit 1
    fi
}
buildMac() {
    local platform=$1
    local arch=$2
    ConfigureForMacOS $arch
    InnerBuild $platform $arch
}
buildMacCatalyst() {
    local platform=$1
    local arch=$2
    ConfigureForMacCatalyst $arch
    InnerBuild $platform $arch

}
buildIOS() {
    local platform=$1
    local arch=$2
    ConfigureForIOS $arch
    InnerBuild $platform $arch

}
buildTVOS() {
    local platform=$1
    local arch=$2
    ConfigureForTVOS $arch
    InnerBuild $platform $arch
}
function PackageToLibrary() {
    local platform=$1
}
function CreateModulemap() {
    local framework=$1
    mkdir -p $framework/Modules
	cp ffmpeg-umbrella.h $framework/Headers
    cp module.modulemap $framework/Modules
}
PrepareYasm
BuildAll
CreateXCFramework
