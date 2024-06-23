#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

top="$(pwd)"
stage="$top"/stage
stage_bin_debug="$stage/bin/debug"
stage_bin_release="$stage/bin/release"
stage_lib_debug="$stage/lib/debug"
stage_lib_release="$stage/lib/release"

VIVOX_SOURCE_DIR="$top/vivox"
VIVOX_VERSION="4.10.0000.32327.5fc3fe7c.558436"

# load autobuild provided shell functions and variables
case "$AUTOBUILD_PLATFORM" in
    windows*)
        autobuild="$(cygpath -u "$AUTOBUILD")"
    ;;
    *)
        autobuild="$AUTOBUILD"
    ;;
esac
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

echo "${VIVOX_VERSION}" > "${stage}/VERSION.txt"

# Create the staging license folder
mkdir -p "$stage/LICENSES"

#Create the staging debug and release folders
mkdir -p "$stage_bin_debug"
mkdir -p "$stage_bin_release"
mkdir -p "$stage_lib_debug"
mkdir -p "$stage_lib_release"

COPYFLAGS=""
pushd "$VIVOX_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            if [ "$AUTOBUILD_ADDRSIZE" = 32 ]
            then platformdir="win32"
            else platformdir="win64"
            fi

	        COPYFLAGS="-dR --preserve=mode,timestamps"
            cp $COPYFLAGS ${platformdir}/*.exe "$stage_bin_release"
            cp $COPYFLAGS ${platformdir}/*.lib "$stage_lib_release"
            cp $COPYFLAGS ${platformdir}/*.dll "$stage_lib_release"
            cp $COPYFLAGS ${platformdir}/*.pdb "$stage_lib_release"
        ;;
        darwin*)
	        COPYFLAGS="-a"
            cp $COPYFLAGS darwin64/SLVoice "$stage_bin_release"
            cp $COPYFLAGS darwin64/*.dylib "$stage_lib_release"
            if [ -n "${APPLE_SIGNATURE:=""}" -a -n "${APPLE_KEY:=""}" -a -n "${APPLE_KEYCHAIN:=""}" ]; then
                KEYCHAIN_PATH="$HOME/Library/Keychains/$APPLE_KEYCHAIN"
                security unlock-keychain -p $APPLE_KEY $KEYCHAIN_PATH
                pushd "$stage_lib_release"
                    codesign --keychain "$KEYCHAIN_PATH" --force --timestamp --sign "$APPLE_SIGNATURE" libortp.dylib || true
                    codesign --keychain "$KEYCHAIN_PATH" --force --timestamp --sign "$APPLE_SIGNATURE" libvivoxsdk.dylib || true
                popd
                pushd "$stage_bin_release"
                    codesign --keychain "$KEYCHAIN_PATH" --sign "$APPLE_SIGNATURE" \
                        --entitlements "$VIVOX_SOURCE_DIR/darwin64/slvoice.entitlements.plist" \
                        -o "runtime,library" --force --timestamp SLVoice || true
                popd
                security lock-keychain $KEYCHAIN_PATH
            else
                echo "Code signing not configured; skipping codesign."
            fi
        ;;
        linux*)
	        COPYFLAGS="-a"
            cp $COPYFLAGS linux/SLVoice "$stage_bin_release"
            cp $COPYFLAGS linux/*.so* "$stage_lib_release"
    
            mkdir -p "$stage_bin_release/win32"
            mkdir -p "$stage_bin_release/win64"
            cp $COPYFLAGS win32/*.* "$stage_bin_release/win32"
            cp $COPYFLAGS win64/*.* "$stage_bin_release/win64"
         ;;
    esac

    # Copy License
    cp "vivox_licenses.txt" "$stage/LICENSES/vivox_licenses.txt"
    cp "vivox_sdk_license.txt" "$stage/LICENSES/vivox_sdk_license.txt"
popd
