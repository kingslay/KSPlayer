LIBRARY_FILE="$LIBRARY_NAME.a"
XCFRAMEWORK_FILE="$LIBRARY_NAME.xcframework"
PLATFORMS="ios tvos macos maccatalyst"
# PLATFORMS="maccatalyst"
XCODE_PATH=$(xcode-select -p)
function Architectures() {
    local platform=$1
    case $platform in
    ios) echo "arm64 x86_64" ;;
    tvos) echo "arm64 x86_64" ;;
    macos) echo "x86_64" ;;
    maccatalyst) echo "x86_64" ;;
    esac
}
function Build() {
    local platform=$1
    local arch=$2

    echo "${ORANGE}Configuring for platform: $platform, arch: $arch"
    local current_dir=$(pwd)
    local TARGETDIR="$current_dir/$LIBRARY_NAME/$platform/scratch/$arch"
    mkdir -p $TARGETDIR
    echo $TARGETDIR
    case $platform in
    ios) buildIOS $platform $arch $TARGETDIR ;;
    tvos) buildTVOS $platform $arch $TARGETDIR ;;
    macos) buildMac $platform $arch $TARGETDIR ;;
    maccatalyst) buildMacCatalyst $platform $arch $TARGETDIR ;;
    esac
}
function BuildAll() {
    echo "${ORANGE}Building for platforms:${MAGENTA} $PLATFORMS ${NOCOLOR}"

    for TMPPLATFORM in $PLATFORMS; do
        rm -rf "$LIBRARY_NAME/$TMPPLATFORM"
        local archs="$(Architectures $TMPPLATFORM)"
        echo "${ORANGE}>>> Building platform: $TMPPLATFORM Available ARCHS:${MAGENTA} $archs ${NOCOLOR}"

        for arch in $archs; do
            Build $TMPPLATFORM $arch
            PackageToLibrary $TMPPLATFORM $arch
        done

    done
}

function CreateXCFramework() {
    echo "Creating $LIBRARY_NAME.framework"
    echo "${ORANGE}Creating framework: $PLATFORMS ${NOCOLOR}"

    local framework_arguments=""

    rm -rf $XCFRAMEWORK_FILE

    for PLATFORM in $PLATFORMS; do
        local archs="$(Architectures $PLATFORM)"

        for arch in $archs; do
            local thin_dir="$LIBRARY_NAME/$PLATFORM/thin/$arch"
            framework=$thin_dir/$LIBRARY_NAME.framework
            rm -rf $framework
            mkdir -p $framework/Headers
            libtool -no_warning_for_no_symbols -static -o $framework/$LIBRARY_NAME $thin_dir/lib/*.a
            cp -R $thin_dir/include/ $framework/Headers/
            CreateModulemap $framework
            framework_arguments="$framework_arguments -framework $framework"
        done
    done

    echo $XCFRAMEWORK_FILE

    xcodebuild -create-xcframework \
        $framework_arguments \
        -output "$XCFRAMEWORK_FILE"
}
