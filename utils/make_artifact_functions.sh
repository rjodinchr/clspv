#!/usr/bin/bash

set -xe

CLSPV_ROOT="$(dirname $(realpath "${BASH_SOURCE[0]}"))/.."
NDK_NAME="android-ndk-r27c"
LIBCLC_BUILD_FOLDER="build_libclc"
CLSPV_BUILD_FOLDER="build_clspv"
LLVM_VERSION="19.1.3"

setup_folder() {
    [ $# -eq 1 ]
    local BUILD_FOLDER="$1"
    mkdir "${BUILD_FOLDER}"
    cd "${BUILD_FOLDER}"
}

download_ndk() {
    local NDK_ZIP="${NDK_NAME}-linux.zip"
    curl -L "https://dl.google.com/android/repository/${NDK_ZIP}" \
         --output "${NDK_ZIP}"
    unzip -q "${NDK_ZIP}"
    rm -f "${NDK_ZIP}"
}

download_llvm() {
    [ $# -eq 1 ]
    local LLVM_ARCHIVE_NAME="$1"
    curl -L "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_ARCHIVE_NAME}.tar.xz" \
         --output "${LLVM_ARCHIVE_NAME}.tar.xz"
    tar -xf "${LLVM_ARCHIVE_NAME}.tar.xz"
    rm -f "${LLVM_ARCHIVE_NAME}.tar.xz"
}

cmake_configure() {
    [ $# -ge 1 ]
    local ARCHIVE_NAME="$1"
    shift

    cmake -B "${CLSPV_BUILD_FOLDER}" -S "${CLSPV_ROOT}" -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="${ARCHIVE_NAME}" \
          -DCMAKE_CXX_FLAGS="-fuse-ld=lld -Wno-unused-command-line-argument -Wno-unknown-warning-option -Wno-deprecated-declarations" \
          $@
}

make_archive() {
    [ $# -ge 3 ]
    local ARCHIVE_NAME_SUFFIX="$1"
    local CREATE_ZIP="$2"
    local STRIP="$3"
    shift 3

    local ARCHIVE_NAME="clspv-$(git rev-parse --short origin/main)-${ARCHIVE_NAME_SUFFIX}"

    cmake_configure "${ARCHIVE_NAME}" $@
    cmake --build "${CLSPV_BUILD_FOLDER}" --config Release
    cmake --install "${CLSPV_BUILD_FOLDER}" --config Release

    cmake_configure "${ARCHIVE_NAME}" "-DCLSPV_SHARED_LIB=1" $@
    cmake --build "${CLSPV_BUILD_FOLDER}" --config Release --target clspv_core
    cmake --install "${CLSPV_BUILD_FOLDER}" --config Release

    if [ "${STRIP}" != "NO_STRIP" ]
    then
        for binary in "${ARCHIVE_NAME}"/bin/*
        do
            "${STRIP}" "${binary}" -o "${binary}"
        done
        for library in "${ARCHIVE_NAME}"/lib/*
        do
            "${STRIP}" "${library}" -o "${library}"
        done
    fi

    if [ "${CREATE_ZIP}" == "CREATE_ZIP" ]
    then
        zip -r "${ARCHIVE_NAME}.zip" "${ARCHIVE_NAME}"
    fi
}

llvm_archive_name() {
    [ $# -eq 1 ]
    local DISTRO="$1"

    echo "LLVM-${LLVM_VERSION}-${DISTRO}"
}

make_native() {
    [ $# -ge 5 ]
    local DISTRO="$1"
    local CLANGXX_BINARY="$2"
    local CLANG_BINARY="$3"
    local CREATE_ZIP="$4"
    local STRIP="$5"
    shift 5

    local LLVM_ARCHIVE_NAME="$(llvm_archive_name ${DISTRO})"

    setup_folder "build-artifact-${DISTRO}"
    download_llvm "${LLVM_ARCHIVE_NAME}"
    make_archive "${DISTRO}" \
                 "${CREATE_ZIP}" \
                 "${STRIP}" \
                 "-DCMAKE_C_COMPILER=$(pwd)/${LLVM_ARCHIVE_NAME}/bin/${CLANG_BINARY}" \
                 "-DCMAKE_CXX_COMPILER=$(pwd)/${LLVM_ARCHIVE_NAME}/bin/${CLANGXX_BINARY}" \
                 $@
}

make_android_from_linux() {
    [ $# -eq 2 ]
    local ANDROID_ABI="$1"
    local STRIP="$2"

    local LLVM_ARCHIVE_NAME="$(llvm_archive_name "Linux-X64")"
    local ARCHIVE_NAME_SUFFIX="Android-${ANDROID_ABI}"

    setup_folder "build-artifact-${ARCHIVE_NAME_SUFFIX}"
    download_llvm "${LLVM_ARCHIVE_NAME}"
    download_ndk
    make_archive "${ARCHIVE_NAME_SUFFIX}" \
                 "CREATE_ZIP" \
                 "${STRIP}" \
                 "-DCMAKE_TOOLCHAIN_FILE=$(pwd)/${NDK_NAME}/build/cmake/android.toolchain.cmake" \
                 "-DANDROID_ABI=${ANDROID_ABI}" \
                 "-DANDROID_PLATFORM=35"
}
