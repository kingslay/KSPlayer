#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR


# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")


variant_for_slice()
{
  case "$1" in
  "Libavcodec.xcframework/ios-arm64")
    echo ""
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavcodec.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavcodec.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libavcodec.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavcodec.xcframework/xros-arm64")
    echo ""
    ;;
  "Libavcodec.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "Libavfilter.xcframework/ios-arm64")
    echo ""
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavfilter.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavfilter.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libavfilter.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavfilter.xcframework/xros-arm64")
    echo ""
    ;;
  "Libavfilter.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "Libavformat.xcframework/ios-arm64")
    echo ""
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavformat.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavformat.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libavformat.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavformat.xcframework/xros-arm64")
    echo ""
    ;;
  "Libavformat.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/ios-arm64")
    echo ""
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavutil.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libavutil.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/xros-arm64")
    echo ""
    ;;
  "Libavutil.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "Libswresample.xcframework/ios-arm64")
    echo ""
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswresample.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libswresample.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libswresample.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswresample.xcframework/xros-arm64")
    echo ""
    ;;
  "Libswresample.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "Libswscale.xcframework/ios-arm64")
    echo ""
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswscale.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libswscale.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "Libswscale.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswscale.xcframework/xros-arm64")
    echo ""
    ;;
  "Libswscale.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libshaderc_combined.xcframework/ios-arm64")
    echo ""
    ;;
  "libshaderc_combined.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "libshaderc_combined.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libshaderc_combined.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libshaderc_combined.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libshaderc_combined.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libshaderc_combined.xcframework/xros-arm64")
    echo ""
    ;;
  "libshaderc_combined.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "MoltenVK.xcframework/ios-arm64")
    echo ""
    ;;
  "MoltenVK.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "MoltenVK.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "MoltenVK.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "MoltenVK.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "lcms2.xcframework/ios-arm64")
    echo ""
    ;;
  "lcms2.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "lcms2.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "lcms2.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "lcms2.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "lcms2.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "lcms2.xcframework/xros-arm64")
    echo ""
    ;;
  "lcms2.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libdav1d.xcframework/ios-arm64")
    echo ""
    ;;
  "libdav1d.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "libdav1d.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libdav1d.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libdav1d.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libdav1d.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libdav1d.xcframework/xros-arm64")
    echo ""
    ;;
  "libdav1d.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libplacebo.xcframework/ios-arm64")
    echo ""
    ;;
  "libplacebo.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "libplacebo.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libplacebo.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libplacebo.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libplacebo.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libplacebo.xcframework/xros-arm64")
    echo ""
    ;;
  "libplacebo.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libfontconfig.xcframework/ios-arm64")
    echo ""
    ;;
  "libfontconfig.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "libfontconfig.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libfontconfig.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libfontconfig.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libfontconfig.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libfontconfig.xcframework/xros-arm64")
    echo ""
    ;;
  "libfontconfig.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "gmp.xcframework/ios-arm64")
    echo ""
    ;;
  "gmp.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "gmp.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "gmp.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "gmp.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "gmp.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "gmp.xcframework/xros-arm64")
    echo ""
    ;;
  "gmp.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "nettle.xcframework/ios-arm64")
    echo ""
    ;;
  "nettle.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "nettle.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "nettle.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "nettle.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "nettle.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "nettle.xcframework/xros-arm64")
    echo ""
    ;;
  "nettle.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "hogweed.xcframework/ios-arm64")
    echo ""
    ;;
  "hogweed.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "hogweed.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "hogweed.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "hogweed.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "hogweed.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "hogweed.xcframework/xros-arm64")
    echo ""
    ;;
  "hogweed.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "gnutls.xcframework/ios-arm64")
    echo ""
    ;;
  "gnutls.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "gnutls.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "gnutls.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "gnutls.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "gnutls.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "gnutls.xcframework/xros-arm64")
    echo ""
    ;;
  "gnutls.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libzvbi.xcframework/ios-arm64")
    echo ""
    ;;
  "libzvbi.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libzvbi.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libzvbi.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libzvbi.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libzvbi.xcframework/xros-arm64")
    echo ""
    ;;
  "libzvbi.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  "libsrt.xcframework/ios-arm64")
    echo ""
    ;;
  "libsrt.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "libsrt.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libsrt.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "libsrt.xcframework/tvos-arm64_arm64e")
    echo ""
    ;;
  "libsrt.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "libsrt.xcframework/xros-arm64")
    echo ""
    ;;
  "libsrt.xcframework/xros-arm64-simulator")
    echo "simulator"
    ;;
  esac
}

archs_for_slice()
{
  case "$1" in
  "Libavcodec.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavcodec.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libavcodec.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "Libavfilter.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavfilter.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libavfilter.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "Libavformat.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavformat.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libavformat.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "Libavutil.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavutil.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libavutil.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "Libswresample.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libswresample.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libswresample.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "Libswscale.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libswscale.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "Libswscale.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libshaderc_combined.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libshaderc_combined.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "libshaderc_combined.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libshaderc_combined.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libshaderc_combined.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libshaderc_combined.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libshaderc_combined.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libshaderc_combined.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "MoltenVK.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "MoltenVK.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "MoltenVK.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "MoltenVK.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "MoltenVK.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "lcms2.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "lcms2.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "lcms2.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "lcms2.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "lcms2.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "lcms2.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "lcms2.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "lcms2.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libdav1d.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libdav1d.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "libdav1d.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libdav1d.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libdav1d.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libdav1d.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libdav1d.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libdav1d.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libplacebo.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libplacebo.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "libplacebo.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libplacebo.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libplacebo.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libplacebo.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libplacebo.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libplacebo.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libfontconfig.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libfontconfig.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "libfontconfig.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libfontconfig.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libfontconfig.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libfontconfig.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libfontconfig.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libfontconfig.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "gmp.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "gmp.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "gmp.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "gmp.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "gmp.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "gmp.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "gmp.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "gmp.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "nettle.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "nettle.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "nettle.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "nettle.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "nettle.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "nettle.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "nettle.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "nettle.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "hogweed.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "hogweed.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "hogweed.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "hogweed.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "hogweed.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "hogweed.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "hogweed.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "hogweed.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "gnutls.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "gnutls.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "gnutls.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "gnutls.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "gnutls.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "gnutls.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "gnutls.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "gnutls.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libzvbi.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libzvbi.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libzvbi.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libzvbi.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libzvbi.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libzvbi.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libzvbi.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  "libsrt.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "libsrt.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "libsrt.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libsrt.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "libsrt.xcframework/tvos-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "libsrt.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "libsrt.xcframework/xros-arm64")
    echo "arm64"
    ;;
  "libsrt.xcframework/xros-arm64-simulator")
    echo "arm64"
    ;;
  esac
}

copy_dir()
{
  local source="$1"
  local destination="$2"

  # Use filter instead of exclude so missing patterns don't throw errors.
  echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \"- CVS/\" --filter \"- .svn/\" --filter \"- .git/\" --filter \"- .hg/\" \"${source}*\" \"${destination}\""
  rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}"/* "${destination}"
}

SELECT_SLICE_RETVAL=""

select_slice() {
  local xcframework_name="$1"
  xcframework_name="${xcframework_name##*/}"
  local paths=("${@:2}")
  # Locate the correct slice of the .xcframework for the current architectures
  local target_path=""

  # Split archs on space so we can find a slice that has all the needed archs
  local target_archs=$(echo $ARCHS | tr " " "\n")

  local target_variant=""
  if [[ "$PLATFORM_NAME" == *"simulator" ]]; then
    target_variant="simulator"
  fi
  if [[ ! -z ${EFFECTIVE_PLATFORM_NAME+x} && "$EFFECTIVE_PLATFORM_NAME" == *"maccatalyst" ]]; then
    target_variant="maccatalyst"
  fi
  for i in ${!paths[@]}; do
    local matched_all_archs="1"
    local slice_archs="$(archs_for_slice "${xcframework_name}/${paths[$i]}")"
    local slice_variant="$(variant_for_slice "${xcframework_name}/${paths[$i]}")"
    for target_arch in $target_archs; do
      if ! [[ "${slice_variant}" == "$target_variant" ]]; then
        matched_all_archs="0"
        break
      fi

      if ! echo "${slice_archs}" | tr " " "\n" | grep -F -q -x "$target_arch"; then
        matched_all_archs="0"
        break
      fi
    done

    if [[ "$matched_all_archs" == "1" ]]; then
      # Found a matching slice
      echo "Selected xcframework slice ${paths[$i]}"
      SELECT_SLICE_RETVAL=${paths[$i]}
      break
    fi
  done
}

install_xcframework() {
  local basepath="$1"
  local name="$2"
  local package_type="$3"
  local paths=("${@:4}")

  # Locate the correct slice of the .xcframework for the current architectures
  select_slice "${basepath}" "${paths[@]}"
  local target_path="$SELECT_SLICE_RETVAL"
  if [[ -z "$target_path" ]]; then
    echo "warning: [CP] $(basename ${basepath}): Unable to find matching slice in '${paths[@]}' for the current build architectures ($ARCHS) and platform (${EFFECTIVE_PLATFORM_NAME-${PLATFORM_NAME}})."
    return
  fi
  local source="$basepath/$target_path"

  local destination="${PODS_XCFRAMEWORKS_BUILD_DIR}/${name}"

  if [ ! -d "$destination" ]; then
    mkdir -p "$destination"
  fi

  copy_dir "$source/" "$destination"
  echo "Copied $source to $destination"
}

install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libavcodec.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libavfilter.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libavformat.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libavutil.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libswresample.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/Libswscale.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libshaderc_combined.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/MoltenVK.xcframework" "FFmpegKit/FFmpegKit" "library" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/lcms2.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libdav1d.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libplacebo.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libfontconfig.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/gmp.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/nettle.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/hogweed.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/gnutls.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libzvbi.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../../FFmpegKit/Sources/libsrt.xcframework" "FFmpegKit/FFmpegKit" "framework" "tvos-arm64_arm64e" "tvos-arm64_x86_64-simulator"

