#!/usr/bin/bash

set -x

SCRIPT_DIR="$(dirname $(realpath "${BASH_SOURCE[0]}"))"
source "${SCRIPT_DIR}/make_artifact_functions.sh"
make_native "Windows-X64" clang++.exe clang.exe "NO_ZIP" "NO_STRIP" "-DLLVM_HOST_TRIPLE=x86_64-w64-windows-gnu"
