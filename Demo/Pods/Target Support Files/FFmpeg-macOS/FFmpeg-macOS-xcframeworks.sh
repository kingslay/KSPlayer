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
  "Libavcodec.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavcodec.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libavcodec.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libavcodec.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavfilter.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavfilter.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavfilter.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavfilter.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavformat.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavformat.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libavformat.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libavformat.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libavutil.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libavutil.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libavutil.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libswresample.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswresample.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswresample.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libswresample.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libswscale.xcframework/ios-arm64_arm64e")
    echo ""
    ;;
  "Libswscale.xcframework/tvos-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Libswscale.xcframework/macos-arm64_x86_64")
    echo ""
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "maccatalyst"
    ;;
  "Libswscale.xcframework/tvos-arm64")
    echo ""
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  esac
}

archs_for_slice()
{
  case "$1" in
  "Libavcodec.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libavcodec.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavcodec.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavfilter.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavfilter.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libavformat.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libavformat.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavformat.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libavutil.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libavutil.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libavutil.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswresample.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libswresample.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libswscale.xcframework/ios-arm64_arm64e")
    echo "arm64 arm64e"
    ;;
  "Libswscale.xcframework/tvos-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/macos-arm64_x86_64")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-maccatalyst")
    echo "arm64 x86_64"
    ;;
  "Libswscale.xcframework/tvos-arm64")
    echo "arm64"
    ;;
  "Libswscale.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
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

install_xcframework "${PODS_ROOT}/../../Sources/Libavcodec.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"
install_xcframework "${PODS_ROOT}/../../Sources/Libavfilter.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"
install_xcframework "${PODS_ROOT}/../../Sources/Libavformat.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"
install_xcframework "${PODS_ROOT}/../../Sources/Libavutil.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"
install_xcframework "${PODS_ROOT}/../../Sources/Libswresample.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"
install_xcframework "${PODS_ROOT}/../../Sources/Libswscale.xcframework" "FFmpeg/FFmpeg" "framework" "macos-arm64_x86_64"

