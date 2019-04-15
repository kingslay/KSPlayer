#!/bin/sh
if [ -z "$platform" ]
then
  platform="iOS"
fi
COMPILE="y"
LIPO="y"
debug="--disable-debug"
DEPLOYMENT_TARGET="9.0"
if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else 
		if [ "$*" = "debug" ]
		then
			debug="--enable-debug"
		else
			ARCHS="$*"
			if [ $# -eq 1 ]
			then
				# skip lipo
				LIPO=
			fi
		fi
	fi
fi
if [ "$platform" = "iOS" ]
then
	SIMULATORPLATFORM="iphonesimulator"
	ARMPLATFORM="iphoneos"
	ARCHS="armv7 arm64 i386 x86_64"
	SIMULATORVERSIONMIN="-mios-simulator-version-min=9.0"
	VERSIONMIN="-mios-version-min=9.0"
else
	if [ "$platform" = "tvOS" ]
	then
		SIMULATORPLATFORM="appletvsimulator"
		ARMPLATFORM="appletvos"
		ARCHS="arm64 x86_64"
		SIMULATORVERSIONMIN="-mtvos-simulator-version-min=10.2"
		VERSIONMIN="-mtvos-version-min=10.2"
	else
		SIMULATORPLATFORM="macosx"
		ARMPLATFORM="macosx"
		ARCHS="x86_64"
		SIMULATORVERSIONMIN="-mmacos-version-min=10.10"
		VERSIONMIN="-mmacos-version-min=10.10"
	fi
fi
FAT="FFmpeg-$platform"
# directories
FF_VERSION="4.1"
if [[ $FFMPEG_VERSION != "" ]]; then
  FF_VERSION=$FFMPEG_VERSION
fi
##### Add Begin #####
# OpenSSL
OPENSSL=`pwd`/"openssl-$platform"
#####  Add End  #####
SOURCE="ffmpeg-$FF_VERSION"
SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"
rm -rf FAT
rm -rf THIN
rm -rf SCRATCH
# absolute path to x264 library
#X264=`pwd`/fat-x264

#FDK_AAC=`pwd`/../fdk-aac-build-script-for-iOS/fdk-aac-ios
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --prefix=PREFIX"
CONFIGURE_FLAGS="--enable-optimizations --enable-pic --enable-neon"
# Licensing options:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-gpl"
# CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-version3"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-nonfree"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS $debug"

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

# External library support:
CONFIGURE_FLAGS="$CONFIGURE_FLAGS --disable-iconv"

if [ "$X264" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264"
fi

if [ "$FDK_AAC" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac --enable-nonfree"
fi
if [ "$OPENSSL" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-openssl"
fi
# avresample
#CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
			CC="xcrun -sdk $SIMULATORPLATFORM clang"
		    CFLAGS="$CFLAGS $SIMULATORVERSIONMIN"
			FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --disable-asm --disable-mmx --assert-level=2"
		else
			CC="xcrun -sdk $ARMPLATFORM clang"
			CFLAGS="$CFLAGS $VERSIONMIN -fembed-bitcode"
			FFMPEG_CFG_FLAGS="$CONFIGURE_FLAGS --enable-small"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
		if [ "$ARCH" = "arm64" ]
		then
		    AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		else
		    AS="gas-preprocessor.pl -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
		if [ "$X264" ]
		then
			CFLAGS="$CFLAGS -I$X264/include"
			LDFLAGS="$LDFLAGS -L$X264/lib"
		fi
		if [ "$FDK_AAC" ]
		then
			CFLAGS="$CFLAGS -I$FDK_AAC/include"
			LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi
		if [ "$OPENSSL" ]
		then
			CFLAGS="$CFLAGS -I$OPENSSL/include"
			LDFLAGS="$LDFLAGS -L$OPENSSL/lib"
		fi

		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    --as="$AS" \
		    $FFMPEG_CFG_FLAGS \
		    --extra-cflags="$CFLAGS" \
			--extra-cxxflags="$FFMPEG_CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" \
		|| exit 1

		make -j3 install $EXPORT || exit 1
		cd $CWD
	done
fi
if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi
echo Done